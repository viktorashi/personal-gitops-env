terraform {
  required_version = "~> 1.12"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "9.7.1"
    }
  }
  backend "s3" {
    key                         = "platform/terraform.tfstate"
    use_lockfile                = true
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

locals {
  settings = jsondecode(file("${path.module}/../settings.json"))
}

# CI uses an ephemeral federated session, not the human administrator's session.
provider "oci" {
  region              = local.settings.region
  auth                = "SecurityToken"
  config_file_profile = var.profile
}
