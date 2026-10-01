terraform {
  required_version = "~> 1.12"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "9.7.1"
    }
  }
  backend "s3" {
    bucket                      = "${local.settings.name}-state"
    region                      = local.settings.region
    endpoints                   = { s3 = "https://${var.namespace}.compat.objectstorage.${local.settings.region}.${local.settings.object_storage_domain}" }
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
  region                              = local.settings.region
  auth                                = var.auth
  config_file_profile                 = var.auth == "SecurityToken" ? var.profile : null
  token_exchange_requested_token_type = "urn:oci:token-type:oci-rpst"
  token_exchange_subject_token_type   = "jwt"
  token_exchange_resource_type        = "githubactions"
  token_exchange_rpst_exp             = "60"
  # Token path, domain URL and client credentials use the provider's OCI_* env vars.
}
