locals {
  subnets = {
    endpoint = "10.42.0.0/24"
    worker   = "10.42.1.0/24"
    edge     = "10.42.2.0/24"
  }
  ingress = {
    endpoint = [
      { source = var.admin_cidr, min = 6443, max = 6443 },
      { source = local.subnets.worker, min = 6443, max = 6443 },
      { source = local.subnets.worker, min = 12250, max = 12250 },
    ]
    worker = [
      { source = local.subnets.endpoint, min = 10250, max = 10250 },
      { source = local.subnets.edge, min = 30000, max = 32767 },
    ]
    edge = [
      { source = "0.0.0.0/0", min = 80, max = 80 },
      { source = "0.0.0.0/0", min = 443, max = 443 },
    ]
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
    "set compute-core quota standard-a1-core-count to ${local.settings.node.ocpus} in tenancy where request.ad = '${var.availability_domain}'",
    "set compute-memory quota standard-a1-memory-count to ${local.settings.node.memory_gbs} in tenancy where request.ad = '${var.availability_domain}'",
    "zero block-storage quotas in tenancy",
    "set block-storage quota total-storage-gb to ${local.settings.storage_limit_gbs} in tenancy where request.ad = '${var.availability_domain}'",
    "set block-storage quota volume-count to 4 in tenancy where request.ad = '${var.availability_domain}'",
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
  cidr_blocks    = ["10.42.0.0/16"]
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
  compartment_id = oci_identity_compartment.this["platform"].id
  vcn_id         = oci_core_vcn.this.id
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.this.id
  }
  route_rules {
    destination_type  = "SERVICE_CIDR_BLOCK"
    destination       = one(data.oci_core_services.this.services).cidr_block
    network_entity_id = oci_core_service_gateway.this.id
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
    for_each = local.ingress[each.key]
    content {
      protocol = "6"
      source   = ingress_security_rules.value.source
      tcp_options {
        min = ingress_security_rules.value.min
        max = ingress_security_rules.value.max
      }
    }
  }
  dynamic "ingress_security_rules" {
    for_each = each.key == "worker" ? [1] : []
    content {
      protocol = "all"
      source   = local.subnets.worker
    }
  }
  ingress_security_rules {
    protocol = "1"
    source   = "10.42.0.0/16"
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
  cidr_block                 = each.value
  display_name               = each.key
  dns_label                  = each.key
  route_table_id             = oci_core_route_table.this.id
  security_list_ids          = [oci_core_security_list.this[each.key].id]
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_volume" "fns" {
  compartment_id      = oci_identity_compartment.this["platform"].id
  availability_domain = var.availability_domain
  display_name        = "fns-data"
  size_in_gbs         = local.settings.data_gbs
  vpus_per_gb         = 10
  depends_on          = [oci_limits_quota.free]
  lifecycle {
    prevent_destroy = true
  }
}
