output "filestore_instance" {
  value       = google_filestore_instance.default
  description = "Google Filestore instance."
}

output "backup_freshness_metric" {
  value = google_cloudfunctions2_function.backup_freshness[0].service_config[0].environment_variables["METRIC"]
}
