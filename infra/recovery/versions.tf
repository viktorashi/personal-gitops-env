terraform {
  required_version = "~> 1.12"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "9.7.1"
    }
  }
}

locals {
  settings = jsondecode(file("${path.module}/../settings.json"))
}

# Human-admin stack: changing Function code would confer backup-deletion power.
provider "oci" {
  region              = local.settings.region
  auth                = "SecurityToken"
  config_file_profile = var.profile
}
