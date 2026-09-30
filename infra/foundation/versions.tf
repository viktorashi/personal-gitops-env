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

# Human-admin stack: neither its state nor its credentials are given to CI.
provider "oci" {
  region              = local.settings.region
  auth                = var.auth
  config_file_profile = var.profile
}
