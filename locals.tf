locals {
  project_id     = var.enable_auto_backup ? data.google_client_config.current.project : null
  project_number = var.enable_auto_backup ? data.google_project.current.number : null
  region         = var.enable_auto_backup ? data.google_client_config.current.region : null
}
