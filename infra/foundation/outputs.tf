locals {
  state_endpoint = "https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${local.settings.region}.${local.settings.object_storage_domain}"
  platform_inputs = {
    compartment_id      = oci_identity_compartment.this["platform"].id
    vcn_id              = oci_core_vcn.this.id
    endpoint_subnet_id  = oci_core_subnet.this["endpoint"].id
    worker_subnet_id    = oci_core_subnet.this["worker"].id
    edge_subnet_id      = oci_core_subnet.this["edge"].id
    availability_domain = local.availability_domain
  }
}

output "platform_inputs" {
  description = "Platform stack inputs; save as foundation.auto.tfvars.json."
  value       = local.platform_inputs
}

output "recovery_inputs" {
  description = "Recovery stack inputs; save as foundation.auto.tfvars.json."
  value = {
    tenancy_ocid          = var.tenancy_ocid
    compartment_id        = oci_identity_compartment.this["recovery"].id
    source_compartment_id = oci_identity_compartment.this["platform"].id
    subnet_id             = oci_core_subnet.this["edge"].id
    volume_id             = oci_core_volume.fns.id
    namespace             = data.oci_objectstorage_namespace.this.namespace
    bucket                = oci_objectstorage_bucket.this["recovery"].name
  }
}

output "volume_id" {
  description = "Protected source volume for the static FNS PV."
  value       = oci_core_volume.fns.id
}

output "state_user_id" {
  description = "User for a separately generated Customer Secret Key."
  value       = oci_identity_user.state.id
}

output "backend_config" {
  description = "Platform backend configuration; save as backend.hcl."
  value       = <<-HCL
    bucket = "${oci_objectstorage_bucket.this["state"].name}"
    region = "${local.settings.region}"
    endpoints = { s3 = "${local.state_endpoint}" }
  HCL
}

output "github_configuration" {
  description = "GitHub environment variable OCI_BOOTSTRAP; not secret."
  value = {
    domain_url = local.identity_domain.url
    backend = {
      bucket    = oci_objectstorage_bucket.this["state"].name
      region    = local.settings.region
      endpoints = { s3 = local.state_endpoint }
    }
    platform_inputs = local.platform_inputs
  }
}

output "github_client_id" {
  description = "GitHub environment secret OCI_CLIENT_ID."
  value       = oci_identity_domains_app.github.name
}

output "github_client_secret" {
  description = "GitHub environment secret OCI_CLIENT_SECRET; also present in human-owned state."
  value       = oci_identity_domains_app.github.client_secret
  sensitive   = true
}
