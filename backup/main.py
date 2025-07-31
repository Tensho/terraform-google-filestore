import google.auth
import time
import requests
import json
import os
import logging
from datetime import datetime
from google.cloud import logging as cloud_logging


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
        r = session.post(url=trigger_run_url, headers=headers, data=json.dumps(post_data))
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
