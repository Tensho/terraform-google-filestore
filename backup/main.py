import google.auth
import time
import requests
import json
import os
import logging
from datetime import datetime, timezone, timedelta
from google.cloud import logging as cloud_logging
from google.cloud import monitoring_v3
from cron_converter import Cron
from flask import jsonify

# Setup logging 
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
numeric_level = getattr(logging, LOG_LEVEL, logging.INFO)
cloud_logging_client = cloud_logging.Client()
cloud_logging_client.setup_logging(log_level=numeric_level)
logger = logging.getLogger(__name__)

PROJECT_ID = os.environ.get("PROJECT_ID")
INSTANCE_LOCATION = os.environ.get("INSTANCE_LOCATION")
INSTANCE_NAME = os.environ.get("INSTANCE_NAME")
INSTANCE_FILE_SHARE_NAME = os.environ.get("INSTANCE_FILE_SHARE_NAME")
BACKUP_REGION = os.environ.get("BACKUP_REGION")
BACKUP_RETENTION = int(os.environ.get("BACKUP_RETENTION", 0))
CRON_SCHEDULE = os.environ.get("CRON_SCHEDULE")
METRIC = os.environ.get("METRIC")
TOLERANCE_MINUTES = int(os.environ.get("TOLERANCE_MINUTES", 30))

try:
    credentials, project = google.auth.default()
    request = google.auth.transport.requests.Request()
    credentials.refresh(request)
    session = google.auth.transport.requests.AuthorizedSession(credentials)
except Exception as e:
    logger.exception("Failed to authenticate with Google Cloud.")
    raise

def get_backup_id():
    return INSTANCE_NAME + '-' + time.strftime("%Y%m%d-%H%M%S")

def parse_truncated_iso(iso_str):
    iso_str = iso_str.rstrip('Z')
    if '.' in iso_str:
        date_part, frac = iso_str.split('.')
        frac = frac[:6]
        iso_str = f"{date_part}.{frac}"
    return datetime.fromisoformat(iso_str)

def cleanup_old_backups(request, number_to_keep):
    """
    Sort backups based on data and retain most recent `number_to_keep` backups. Discard the rest.
    """

    backups_url = f"https://file.googleapis.com/v1/projects/{PROJECT_ID}/locations/{BACKUP_REGION}/backups"
    headers = {'Content-Type': 'application/json'}

    try:
        logger.info(f"Fetching backups from {backups_url}")
        r = session.get(url=backups_url, headers=headers)
        r.raise_for_status()
        data = r.json()
        backups = data.get("backups", [])
        logger.info(f"Found {len(backups)} backups.")
    except Exception as e:
        logger.exception("Error fetching backup list.")
        raise

    try:
        sorted_backups = sorted(
            [{'name': b['name'], 'createTime': b['createTime']} for b in backups],
            key=lambda x: parse_truncated_iso(x['createTime']),
            reverse=True
        )

        for backup in sorted_backups[number_to_keep:]:
            delete_url = f"https://file.googleapis.com/v1/{backup['name']}"
            logger.info(f"Deleting backup: {backup['name']}")
            r = session.delete(url=delete_url, headers=headers)
            r.raise_for_status()
    except Exception as e:
        logger.exception(f"Error during backup cleanup: {e}")
        raise

def create_backup(request):
    """
    The main CloudFunction entrypoint. 
    """
    backup_id = get_backup_id()
    backups_url = f"https://file.googleapis.com/v1/projects/{PROJECT_ID}/locations/{BACKUP_REGION}/backups?backupId={backup_id}"
    headers = {'Content-Type': 'application/json'}
    post_data = {
        "description": "Filestore auto backup managed by Cloud Run Function",
        "source_instance": f"projects/{PROJECT_ID}/locations/{INSTANCE_LOCATION}/instances/{INSTANCE_NAME}",
        "source_file_share": INSTANCE_FILE_SHARE_NAME
    }

    try:
        logger.info(f"Triggering backup creation: {backup_id}")
        r = session.post(url=backups_url, headers=headers, data=json.dumps(post_data))
        logger.info("Backup successfully initiated.")
        r.raise_for_status()
    except Exception as e:
        logger.exception(f"Error while creating backup: {e}")
        raise

    if BACKUP_RETENTION > 0: # Retain all backups if set to 0
        try:
            logger.info(f"Cleaning up old backups. Retaining latest {BACKUP_RETENTION}.")
            cleanup_old_backups(request, BACKUP_RETENTION)
            return json.dumps({"status": "Backup started. Cleanup started."})
        except Exception as e:
            logger.warning("Backup started, but cleanup failed.")
            return json.dumps({"status": "Backup started. Cleanup failed.", "error": str(e)})

    return "Backup creation has begun!"

def check_backup_freshness(request):
    """
    Validate if the most recent backup matches the cron schedule.
    Publishes a binary custom metric: 1 = fresh, 0 = stale.
    """
    backups_url = f"https://file.googleapis.com/v1/projects/{PROJECT_ID}/locations/{BACKUP_REGION}/backups"
    headers = {'Content-Type': 'application/json'}

    try:
        logger.info(f"Fetching backups for freshness check from {backups_url}")
        r = session.get(url=backups_url, headers=headers)
        r.raise_for_status()
        data = r.json()
        backups = data.get("backups", [])
    except Exception as e:
        logger.exception("Error fetching backup list for freshness check.")
        raise

    freshness_ok = 0
    if backups:
        # Find the most recent backup
        latest_backup = max(backups, key=lambda b: parse_truncated_iso(b["createTime"]))
        latest_time = parse_truncated_iso(latest_backup["createTime"]).replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)

        # Compute the most recent expected backup time according to cron
        cron = Cron(CRON_SCHEDULE)
        last_expected_time = cron.schedule(now).prev()

        # Allow tolerance window
        tolerance_delta = timedelta(minutes=TOLERANCE_MINUTES)
        freshness_ok = int(latest_time >= (last_expected_time - tolerance_delta))

        logger.info(f"Latest backup at {latest_time}, expected after {last_expected_time}, freshness_ok={freshness_ok}")
    else:
        logger.warning("No backups found during freshness check.")

    # Publish custom metric
    monitoring_client = monitoring_v3.MetricServiceClient()
    series = monitoring_v3.TimeSeries()
    series.metric.type = METRIC
    series.resource.type = "global"
    series.resource.labels["project_id"] = PROJECT_ID

    now = datetime.now(timezone.utc)
    interval = monitoring_v3.TimeInterval(
        end_time={"seconds": int(now.timestamp()), "nanos": int(now.microsecond * 1000)}
    )

    point = monitoring_v3.Point(
        interval=interval,
        value=monitoring_v3.TypedValue(int64_value=freshness_ok),
    )

    series.points.append(point)

    try:
        monitoring_client.create_time_series(
            name=f"projects/{PROJECT_ID}", time_series=[series]
        )
        logger.info(f"Pushed freshness metric: {freshness_ok}")
    except Exception as e:
        logger.exception("Failed to push freshness metric.")
        raise

    return jsonify({
        "freshness_ok": freshness_ok,
        "latest_backup_time": latest_time.isoformat() if backups else None,
        "expected_time": last_expected_time.isoformat() if backups else None
    })
