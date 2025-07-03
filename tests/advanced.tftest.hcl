run "advanced" {
  variables {
    location = "europe-west2-a"

    name        = "advanced"
    description = "Managed by Terraform Test"
    tier        = "ZONAL"
    protocol    = "NFS_V4_1"

    file_shares = {
      name        = "warehouse"
      capacity_gb = 1024

      nfs_export_options = [
        {
          ip_ranges   = ["10.0.0.0/24"]
          access_mode = "READ_WRITE"
          squash_mode = "NO_ROOT_SQUASH"
        },
        {
          ip_ranges   = ["10.10.0.0/24"]
          access_mode = "READ_ONLY"
          squash_mode = "ROOT_SQUASH"
          anon_uid    = 123
          anon_gid    = 456
        },
      ]
    }

    networks = {
      network           = "default"
      modes             = ["MODE_IPV4"]
      connect_mode      = "DIRECT_PEERING"
      reserved_ip_range = "10.0.0.0/24"
    }

    # kms_key_name = "projects/test/locations/global/keyRings/test/cryptoKeys/test"
    #
    # deletion_protection_enabled = true
    # deletion_protection_reason  = "VIP"

    # performance_config = {
    #   iops_per_tb = {
    #     max_iops_per_tb = 1000
    #   }
    #
    #   # fixed_iops = {
    #   #   max_iops = 1000
    #   # }
    # }
  }

  assert {
    condition     = length(google_filestore_instance.default) > 0
    error_message = "Google Filestore instance has not been created"
  }
}
