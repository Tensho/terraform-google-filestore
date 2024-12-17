# Google Filestore Terraform Module

Terraform module to manage [Google Filestore](https://cloud.google.com/filestore) service resource (batteries included).

## Usage

```hcl
module "example" {
  source  = "Tensho/filestore/google"
  version = "1.0.0"

  name = "Example"
  description = "Managed by Terraform Test"
  tier        = "STANDARD"
  protocol    = "NFS_V3"
  
  file_shares = {
    name        = "warehouse"
    capacity_gb = 1024
  
    nfs_export_options = [
      {
        ip_ranges = ["10.0.0.0/24"]
        access_mode = "READ_WRITE"
        squash_mode = "NO_ROOT_SQUASH"
      },
      {
        ip_ranges = ["10.10.0.0/24"]
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
  }
  
  kms_key_name = "projects/example/locations/global/keyRings/example/cryptoKeys/example"
  
  deletion_protection_enabled = true
  deletion_protection_reason  = "VIP"
  
  performance_config = {
    iops_per_tb = {
      max_iops_per_tb = 1000
    }
  }
}
```

Check out comprehensive examples in [`test`](./test) folder.

## Features

* [ ] Automatic backups

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.12 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.14.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_filestore_instance.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/filestore_instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deletion_protection_enabled"></a> [deletion\_protection\_enabled](#input\_deletion\_protection\_enabled) | Google Filestore instance data deletion protection switch. | `string` | `false` | no |
| <a name="input_deletion_protection_reason"></a> [deletion\_protection\_reason](#input\_deletion\_protection\_reason) | Google Filestore instance data deletion protection reason. | `string` | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | Google Filestore instance description | `string` | `"Managed by Terraform"` | no |
| <a name="input_file_shares"></a> [file\_shares](#input\_file\_shares) | Google Filestore instance file shares. | <pre>object({<br/>    name          = string,<br/>    capacity_gb   = string,<br/>    source_backup = optional(string),<br/>    nfs_export_options = optional(list(object({<br/>      ip_ranges   = list(string)<br/>      access_mode = string<br/>      squash_mode = string<br/>      anon_uid    = optional(number)<br/>      anon_gid    = optional(number)<br/>    })), [])<br/>  })</pre> | n/a | yes |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | Google KMS key name used for Filestore instance data encryption. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Google Filestore instance labels. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Google Filestore instance name | `string` | n/a | yes |
| <a name="input_networks"></a> [networks](#input\_networks) | Google Filestore instance networks. | <pre>object({<br/>    network           = string,<br/>    modes             = list(string),<br/>    connect_mode      = optional(string)<br/>    reserved_ip_range = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_performance_config"></a> [performance\_config](#input\_performance\_config) | Google Filestore instance performance configuration. | <pre>object({<br/>    iops_per_tb = optional(object({<br/>      max_iops_per_tb = number<br/>    }))<br/>    fixed_iops = optional(object({<br/>      max_iops = number<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_protocol"></a> [protocol](#input\_protocol) | Google Filestore instance protocol (NFS\_V3, NFS\_V4\_1) | `string` | `null` | no |
| <a name="input_tier"></a> [tier](#input\_tier) | Google Filestore instance tier (STANDARD, PREMIUM, BASIC\_HDD, BASIC\_SSD, HIGH\_SCALE\_SSD, ZONAL, REGIONAL, ENTERPRISE). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_filestore_instance"></a> [filestore\_instance](#output\_filestore\_instance) | Google Filestore instance. |
<!-- END_TF_DOCS -->

## Requirements

### IAM

User or service account credentials with the following roles must be used to provision the resources of this module:

* Cloud Filestore Editor: `roles/file.editor`

The [Project Factory module](https://registry.terraform.io/modules/terraform-google-modules/project-factory/google) and
the IAM module may be used in combination to provision a service account with the necessary roles applied.

### APIs

A project with the following APIs enabled must be used to host the resources of this module:

* Google Filestore API: `file.googleapis.com`

The [Project Factory module](https://registry.terraform.io/modules/terraform-google-modules/project-factory/google) can
be used to provision a project with the necessary APIs enabled.

## Contributing

This project uses [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/).

### Prerequisites

#### MacOS

```shell
brew install pre-commit tfswitch terraform-docs tflint
pre-commit install --install-hooks
```

#### Provider Authentication

```shell
gcloud auth application-default login --project=terraform-test
export GOOGLE_PROJECT=terraform-test
export GOOGLE_REGION=europe-west2
export GOOGLE_ZONE=europe-west2-a
```

### Development & Testing

By default, when you run the terraform test command, Terraform looks for `*.tftest.hcl` files in both the root directory 
and in the `tests` directory.

```shell
terraform init
terraform test
terraform test -filter tests/basic.tftest.hcl -verbose
```