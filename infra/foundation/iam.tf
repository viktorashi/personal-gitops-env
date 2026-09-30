resource "oci_identity_dynamic_group" "workers" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-workers"
  description    = "Managed OKE nodes"
  matching_rule  = "ALL {instance.compartment.id = '${oci_identity_compartment.this["platform"].id}'}"
}

resource "oci_identity_policy" "oke" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-oke"
  description    = "OKE provisioning and node storage/network access"
  statements = [
    "Allow service OKE to manage all-resources in compartment id ${oci_identity_compartment.this["platform"].id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.workers.name} to use volume-family in compartment id ${oci_identity_compartment.this["platform"].id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.workers.name} to manage load-balancers in compartment id ${oci_identity_compartment.this["platform"].id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.workers.name} to use virtual-network-family in compartment id ${oci_identity_compartment.this["platform"].id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.workers.name} to read instances in compartment id ${oci_identity_compartment.this["platform"].id}",
  ]
}

resource "oci_identity_user" "state" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-state"
  description    = "S3-compatible state backend only"
}

resource "oci_identity_group" "state" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-state"
  description    = "State bucket access"
}

resource "oci_identity_user_group_membership" "state" {
  user_id  = oci_identity_user.state.id
  group_id = oci_identity_group.state.id
}

resource "oci_identity_policy" "state" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-state"
  description    = "State and lock objects for the platform backend"
  statements = [
    "Allow group ${oci_identity_group.state.name} to read buckets in compartment id ${oci_identity_compartment.this["state"].id} where target.bucket.name = '${oci_objectstorage_bucket.this["state"].name}'",
    "Allow group ${oci_identity_group.state.name} to manage objects in compartment id ${oci_identity_compartment.this["state"].id} where all {target.bucket.name = '${oci_objectstorage_bucket.this["state"].name}', any {request.permission = 'OBJECT_INSPECT', request.permission = 'OBJECT_READ', request.permission = 'OBJECT_CREATE', request.permission = 'OBJECT_OVERWRITE', request.permission = 'OBJECT_DELETE'}}",
  ]
}
