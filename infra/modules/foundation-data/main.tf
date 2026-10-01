terraform {
  required_version = "~> 1.12"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "9.7.1"
    }
  }
}

variable "tenancy_ocid" {
  description = "Target tenancy; discovery does not read administrator state."
  type        = string
}

data "oci_identity_compartments" "platform" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-platform"
  state          = "ACTIVE"
  lifecycle {
    postcondition {
      condition     = length(self.compartments) == 1
      error_message = "Apply foundation first; expected exactly one platform compartment."
    }
  }
}

data "oci_core_vcns" "this" {
  compartment_id = one(data.oci_identity_compartments.platform.compartments).id
  display_name   = "gitops"
  state          = "AVAILABLE"
  lifecycle {
    postcondition {
      condition     = length(self.virtual_networks) == 1
      error_message = "Expected exactly one foundation VCN."
    }
  }
}

data "oci_core_subnets" "this" {
  for_each       = toset(["oke", "workers", "recovery"])
  compartment_id = one(data.oci_identity_compartments.platform.compartments).id
  vcn_id         = one(data.oci_core_vcns.this.virtual_networks).id
  display_name   = each.key
  state          = "AVAILABLE"
  lifecycle {
    postcondition {
      condition     = length(self.subnets) == 1
      error_message = "Expected exactly one foundation subnet per role."
    }
  }
}

data "oci_core_volumes" "fns" {
  compartment_id = one(data.oci_identity_compartments.platform.compartments).id
  display_name   = "fns-data"
  state          = "AVAILABLE"
  lifecycle {
    postcondition {
      condition     = length(self.volumes) == 1
      error_message = "Expected exactly one protected source volume."
    }
  }
}

output "compartment_id" {
  description = "Platform compartment."
  value       = one(data.oci_identity_compartments.platform.compartments).id
}

output "vcn_id" {
  description = "Foundation VCN."
  value       = one(data.oci_core_vcns.this.virtual_networks).id
}

output "subnet_ids" {
  description = "Subnets by role."
  value       = { for role, result in data.oci_core_subnets.this : role => one(result.subnets).id }
}

output "volume" {
  description = "Protected volume and its availability domain."
  value       = one(data.oci_core_volumes.fns.volumes)
}
