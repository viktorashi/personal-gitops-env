locals {
  subnets = {
    oke      = { cidr = cidrsubnet("10.0.0.0/16", 8, 0), public = true }
    recovery = { cidr = cidrsubnet("10.0.0.0/16", 8, 1), public = false }
  }
}

resource "oci_identity_compartment" "this" {
  for_each       = toset(["platform", "recovery", "state"])
  compartment_id = var.tenancy_ocid
  name           = "gitops-${each.key}"
  description    = "Personal GitOps ${each.key}"
  enable_delete  = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_limits_quota" "free" {
  lifecycle {
    precondition {
      condition     = var.unupgraded_account_confirmed
      error_message = "Verify unupgraded billing before applying; quotas are not a monetary cap."
    }
  }
  compartment_id = var.tenancy_ocid
  name           = "personal-gitops-free"
  description    = "Single-AD free compute/storage envelope; not a billing cap"
  statements = [
    "zero compute quotas in tenancy",
    "zero compute-core quotas in tenancy",
    "zero compute-memory quotas in tenancy",
    "set compute-core quota standard-a1-core-count to ${local.settings.node.ocpus} in tenancy where request.ad = '${local.availability_domain}'",
    "set compute-memory quota standard-a1-memory-count to ${local.settings.node.memory_gbs} in tenancy where request.ad = '${local.availability_domain}'",
    "zero block-storage quotas in tenancy",
    "set block-storage quota total-storage-gb to ${local.settings.storage_limit_gbs} in tenancy where request.ad = '${local.availability_domain}'",
    "set block-storage quota volume-count to 4 in tenancy where request.ad = '${local.availability_domain}'",
    "set block-storage quota backup-count to ${local.settings.backup_limit} in tenancy where request.region = '${local.settings.region}'",
    "zero container-engine quotas in tenancy",
    "set container-engine quota cluster-count to 1 in tenancy where request.region = '${local.settings.region}'",
  ]
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

resource "oci_objectstorage_bucket" "this" {
  for_each       = toset(["state", "recovery"])
  compartment_id = oci_identity_compartment.this[each.key].id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${local.settings.name}-${each.key}"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = oci_identity_compartment.this["platform"].id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "gitops"
  dns_label      = "gitops"
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = oci_identity_compartment.this["platform"].id
  vcn_id         = oci_core_vcn.this.id
  enabled        = true
}

data "oci_core_services" "this" {
  filter {
    name   = "name"
    values = ["All ${local.settings.region_key} Services In Oracle Services Network"]
  }
}

resource "oci_core_service_gateway" "this" {
  compartment_id = oci_identity_compartment.this["platform"].id
  vcn_id         = oci_core_vcn.this.id
  services {
    service_id = one(data.oci_core_services.this.services).id
  }
}

resource "oci_core_route_table" "this" {
  for_each       = local.subnets
  compartment_id = oci_identity_compartment.this["platform"].id
  vcn_id         = oci_core_vcn.this.id
  display_name   = each.key
  route_rules {
    destination_type  = each.value.public ? "CIDR_BLOCK" : "SERVICE_CIDR_BLOCK"
    destination       = each.value.public ? "0.0.0.0/0" : one(data.oci_core_services.this.services).cidr_block
    network_entity_id = each.value.public ? oci_core_internet_gateway.this.id : oci_core_service_gateway.this.id
  }
}

resource "oci_core_security_list" "this" {
  for_each       = local.subnets
  compartment_id = oci_identity_compartment.this["platform"].id
  vcn_id         = oci_core_vcn.this.id
  display_name   = each.key
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
  dynamic "ingress_security_rules" {
    for_each = each.value.public ? [
      { source = var.admin_cidr, port = 6443 },
      { source = "0.0.0.0/0", port = 80 },
    ] : []
    content {
      protocol = "6"
      source   = ingress_security_rules.value.source
      tcp_options {
        min = ingress_security_rules.value.port
        max = ingress_security_rules.value.port
      }
    }
  }
  dynamic "ingress_security_rules" {
    for_each = each.value.public ? [1] : []
    content {
      protocol = "all"
      source   = each.value.cidr
    }
  }
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "this" {
  for_each                   = local.subnets
  compartment_id             = oci_identity_compartment.this["platform"].id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = each.value.cidr
  display_name               = each.key
  dns_label                  = each.key
  route_table_id             = oci_core_route_table.this[each.key].id
  security_list_ids          = [oci_core_security_list.this[each.key].id]
  prohibit_public_ip_on_vnic = !each.value.public
}

resource "oci_core_volume" "fns" {
  compartment_id      = oci_identity_compartment.this["platform"].id
  availability_domain = local.availability_domain
  display_name        = "fns-data"
  size_in_gbs         = local.settings.data_gbs
  vpus_per_gb         = 10
  depends_on          = [oci_limits_quota.free]
  lifecycle {
    prevent_destroy = true
  }
}
