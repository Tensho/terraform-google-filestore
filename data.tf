data "google_client_config" "current" {
}

data "google_project" "current" {
  project_id = data.google_client_config.current.project
}

data "archive_file" "backup_function" {
  count = var.enable_auto_backup ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/backup"
  output_path = "${path.module}/filestore-backup.zip"
}
