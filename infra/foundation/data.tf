data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
  lifecycle {
    postcondition {
      condition     = self.home_region_key == local.settings.region_key
      error_message = "The configured region must be the tenancy's Always Free home region."
    }
  }
}

data "oci_identity_availability_domains" "this" {
  compartment_id = data.oci_identity_tenancy.this.id
  filter {
    name   = "name"
    values = [".*-AD-${var.availability_domain_number}$"]
    regex  = true
  }
  lifecycle {
    postcondition {
      condition     = length(self.availability_domains) == 1
      error_message = "The selected availability domain does not exist in this region."
    }
  }
}

data "oci_identity_domains" "this" {
  compartment_id = data.oci_identity_tenancy.this.id
  display_name   = var.identity_domain_name
  state          = "ACTIVE"
  lifecycle {
    postcondition {
      condition     = length(self.domains) == 1
      error_message = "Select exactly one active Identity Domain by name."
    }
  }
}

locals {
  availability_domain = one(data.oci_identity_availability_domains.this.availability_domains).name
  identity_domain     = one(data.oci_identity_domains.this.domains)
}
