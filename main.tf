resource "google_filestore_instance" "default" {
  location = var.location

  name        = var.name
  description = var.description
  tier        = var.tier
  protocol    = var.protocol

  file_shares {
    name          = var.file_shares.name
    capacity_gb   = var.file_shares.capacity_gb
    source_backup = var.file_shares.source_backup

    dynamic "nfs_export_options" {
      for_each = var.file_shares.nfs_export_options

      content {
        ip_ranges   = nfs_export_options.value.ip_ranges
        access_mode = nfs_export_options.value.access_mode
        squash_mode = nfs_export_options.value.squash_mode
        anon_uid    = nfs_export_options.value.anon_uid
        anon_gid    = nfs_export_options.value.anon_gid
      }
    }
  }

  networks {
    network           = var.networks.network
    modes             = var.networks.modes
    connect_mode      = var.networks.connect_mode
    reserved_ip_range = var.networks.reserved_ip_range
  }

  kms_key_name = var.kms_key_name

  deletion_protection_enabled = var.deletion_protection_enabled
  deletion_protection_reason  = var.deletion_protection_reason

  dynamic "performance_config" {
    for_each = var.performance_config != null ? [var.performance_config] : []

    content {
      dynamic "iops_per_tb" {
        for_each = performance_config.value.iops_per_tb != null ? [performance_config.value.iops_per_tb] : []

        content {
          max_iops_per_tb = performance_config.value.iops_per_tb.max_iops_per_tb
        }
      }

      dynamic "fixed_iops" {
        for_each = performance_config.value.fixed_iops != null ? [performance_config.value.fixed_iops] : []

        content {
          max_iops = performance_config.value.fixed_iops.max_iops
        }
      }
    }
  }

  labels = var.labels
}

###############
# Auto Backup #
###############
resource "google_service_account" "filestore_backup_scheduler" {
  count = var.enable_auto_backup ? 1 : 0

  account_id   = "filestore-backup-scheduler"
  display_name = "Filestore Automatic Backup Scheduler Service Account"
}

resource "google_service_account" "filestore_backup_runner" {
  count = var.enable_auto_backup ? 1 : 0

  account_id   = "filestore-backup-runner"
  display_name = "Filestore Automatic Backup Runner Service Account"
}

resource "google_service_account_iam_binding" "cloudscheduler_agent_filestore_backup_scheduler" {
  count = var.enable_auto_backup ? 1 : 0

  service_account_id = google_service_account.filestore_backup_scheduler[0].id

  role = "roles/cloudscheduler.serviceAgent"

  members = [
    # Built-in Cloud Scheduler service agent created on API enablement
    "serviceAccount:service-${local.project_number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
  ]
}

resource "google_cloud_run_service_iam_binding" "filestore_backup_scheduler_invoker" {
  count = var.enable_auto_backup ? 1 : 0

  service = google_cloudfunctions2_function.backup[0].name

  role = "roles/run.invoker"

  members = [
    google_service_account.filestore_backup_scheduler[0].member
  ]
}

# Unfortunately, there is no resource-based IAM binding for Filestore instance resource
resource "google_project_iam_binding" "filestore_backup_runner_file_editor" {
  count = var.enable_auto_backup ? 1 : 0

  project = data.google_client_config.current[0].project

  role = "roles/file.editor"

  members = [
    google_service_account.filestore_backup_runner[0].member
  ]

  condition {
    title      = "${google_filestore_instance.default.name} instance"
    expression = format(
      "resource.name.startsWith('projects/%s/locations/%s/backups/%s')",
      local.project_id,
      local.region,
      google_filestore_instance.default.name
    )
  }
}

# Extra permissions for listing backups only 
# Cannot easily be combined with above as file.backups.list do not appear to support conditional IAM.
resource "google_project_iam_member" "filestore_backup_runner_list" {
  project = local.project_id
  role    = "roles/file.viewer" 
  member  = google_service_account.filestore_backup_runner[0].member
}

resource "google_storage_bucket_object" "function_source" {
  count = var.enable_auto_backup ? 1 : 0

  bucket = var.auto_backup_function_storage_bucket_name
  name   = "filestore-backup-${data.archive_file.backup_function[0].output_md5}.zip"
  source = data.archive_file.backup_function[0].output_path

  detect_md5hash = data.archive_file.backup_function[0].output_md5
}

resource "google_cloudfunctions2_function" "backup" {
  count = var.enable_auto_backup ? 1 : 0

  name        = "filestore-backup"
  description = "Filestore Automatic Backup"
  location    = var.auto_backup_function_location

  build_config {
    runtime     = "python312"
    entry_point = "create_backup"
    source {
      storage_source {
        bucket = google_storage_bucket_object.function_source[0].bucket
        object = google_storage_bucket_object.function_source[0].name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = var.auto_backup_function_mem
    timeout_seconds       = 60
    service_account_email = google_service_account.filestore_backup_runner[0].email

    environment_variables = {
      PROJECT_ID               = local.project_id
      INSTANCE_LOCATION        = google_filestore_instance.default.location
      INSTANCE_NAME            = google_filestore_instance.default.name
      INSTANCE_FILE_SHARE_NAME = google_filestore_instance.default.file_shares[0].name
      BACKUP_REGION            = local.region
      BACKUP_RETENTION         = var.auto_backup_retention
    }
  }
}

resource "google_cloud_scheduler_job" "backup" {
  count = var.enable_auto_backup ? 1 : 0

  name        = "filestore-backup"
  description = "Filestore Automatic Backup Workflow Scheduler"

  schedule  = var.auto_backup_schedule
  time_zone = var.auto_backup_time_zone

  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions2_function.backup[0].url

    oidc_token {
      service_account_email = google_service_account.filestore_backup_scheduler[0].email
      audience              = google_cloudfunctions2_function.backup[0].url
    }
  }
}
