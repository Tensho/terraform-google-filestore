# Changelog

## [1.2.2](https://github.com/Tensho/terraform-google-filestore/compare/v1.2.1...v1.2.2) (2025-09-23)


### Bug Fixes

* **backups:** backups_url variable reference ([#12](https://github.com/Tensho/terraform-google-filestore/issues/12)) ([b6642b0](https://github.com/Tensho/terraform-google-filestore/commit/b6642b071a7d7a42227c912830dd206b2eb96101))

## [1.2.1](https://github.com/Tensho/terraform-google-filestore/compare/v1.2.0...v1.2.1) (2025-07-31)


### Bug Fixes

* make "file.viewer" iam role binding conditional ([2fb075a](https://github.com/Tensho/terraform-google-filestore/commit/2fb075ae88f49ec88cd40dba42c924345d0cd99e))

## [1.2.0](https://github.com/Tensho/terraform-google-filestore/compare/v1.1.2...v1.2.0) (2025-07-31)


### Features

* **backups:** add basic backup retention policy ([#9](https://github.com/Tensho/terraform-google-filestore/issues/9)) ([7df1768](https://github.com/Tensho/terraform-google-filestore/commit/7df1768b8b9a4ec2362eac022a36687a28511ed3))

## [1.1.2](https://github.com/Tensho/terraform-google-filestore/compare/v1.1.1...v1.1.2) (2025-07-24)


### Bug Fixes

* **backup:** increase backup function memory ([#7](https://github.com/Tensho/terraform-google-filestore/issues/7)) ([bf1666c](https://github.com/Tensho/terraform-google-filestore/commit/bf1666c30cf5ad9f7c050a5b803322ee07b46714))

## [1.1.1](https://github.com/Tensho/terraform-google-filestore/compare/v1.1.0...v1.1.1) (2025-07-03)


### Bug Fixes

* auto_backup_function_storage_bucket_name input vairable description ([2f0bf5d](https://github.com/Tensho/terraform-google-filestore/commit/2f0bf5dedba4b120ab4951387da785b42d841e0e))
* deletion_protection_enabled input variable type ([0f16891](https://github.com/Tensho/terraform-google-filestore/commit/0f168910681d796238d477f21bf086cce392c037))
* undefined locals when automatic backups are disabled ([eb2ad99](https://github.com/Tensho/terraform-google-filestore/commit/eb2ad99395e2d2b42d9a411d82eb81790d5a85fb))

## [1.1.0](https://github.com/Tensho/terraform-google-filestore/compare/v1.0.0...v1.1.0) (2024-12-20)


### Features

* auto (scheduled) backups ([f6bf9f0](https://github.com/Tensho/terraform-google-filestore/commit/f6bf9f0b279aa396be078c060823ee1ae3533b19))

## 1.0.0 (2024-12-17)

### Init

* Set module structure
* Add basic attributes
