variable "location" {
  description = "Google Filestore instance location (zone, region)"
  type        = string
}

variable "name" {
  description = "Google Filestore instance name"
  type        = string
}

variable "description" {
  description = "Google Filestore instance description "
  type        = string
  default     = "Managed by Terraform"
}

variable "tier" {
  description = "Google Filestore instance tier (STANDARD, PREMIUM, BASIC_HDD, BASIC_SSD, HIGH_SCALE_SSD, ZONAL, REGIONAL, ENTERPRISE)."
  type        = string

  validation {
    condition     = contains(["STANDARD", "PREMIUM", "BASIC_HDD", "BASIC_SSD", "HIGH_SCALE_SSD", "ZONAL", "REGIONAL", "ENTERPRISE"], var.tier)
    error_message = "Invalid tier. Must be one of: STANDARD, PREMIUM, BASIC_HDD, BASIC_SSD, HIGH_SCALE_SSD, ZONAL, REGIONAL, ENTERPRISE."
  }
}

variable "file_shares" {
  description = "Google Filestore instance file shares."
  type = object({
    name          = string,
    capacity_gb   = string,
    source_backup = optional(string),
    nfs_export_options = optional(list(object({
      ip_ranges   = list(string)
      access_mode = string
      squash_mode = string
      anon_uid    = optional(number)
      anon_gid    = optional(number)
    })), [])
  })
}

variable "networks" {
  description = "Google Filestore instance networks."
  type = object({
    network           = string,
    modes             = list(string),
    connect_mode      = optional(string)
    reserved_ip_range = optional(string)
  })
}

variable "protocol" {
  description = "Google Filestore instance protocol (NFS_V3, NFS_V4_1)"
  type        = string
  default     = null
}

variable "labels" {
  description = "Google Filestore instance labels."
  type        = map(string)
  default     = {}
}

variable "kms_key_name" {
  description = "Google KMS key name used for Filestore instance data encryption."
  type        = string
  default     = null
}

variable "deletion_protection_enabled" {
  description = "Google Filestore instance data deletion protection switch."
  type        = bool
  default     = false
}

variable "deletion_protection_reason" {
  description = "Google Filestore instance data deletion protection reason."
  type        = string
  default     = null
}

variable "performance_config" {
  description = "Google Filestore instance performance configuration."
  type = object({
    iops_per_tb = optional(object({
      max_iops_per_tb = number
    }))
    fixed_iops = optional(object({
      max_iops = number
    }))
  })
  default = null
}

variable "enable_auto_backup" {
  description = "Google Filestore instance auto backup switch."
  type        = bool
  default     = false
}

variable "auto_backup_schedule" {
  description = "Google Cloud Scheduler job schedule (cron) for Google Filestore instance auto backup."
  type        = string
  default     = "0 0 * * *"
}

variable "auto_backup_time_zone" {
  description = "Google Cloud Scheduler job time zone for Google Filestore instance auto backup."
  type        = string
  default     = "Etc/UTC"
}

variable "auto_backup_function_location" {
  description = "Google Cloud Run Function location (region) for Google Filestore instance auto backup."
  type        = string
  default     = null
}

variable "auto_backup_function_mem" {
  description = "Memory to allocate to the backup function"
  type        = string
  default     = "512Mi"
}

variable "auto_backup_function_storage_bucket_name" {
  description = "Google Cloud Run Function source bucket name for Filestore instance auto backup."
  type        = string
  default     = null
}

variable "auto_backup_retention" {
  description = "Total number of backups to keep. Setting 0 keeps all"
  type        = number
  default     = 0
}
