# Independent PR identity: cloud reads, state reads, no lock/state writes.
variable "state_plan_user_email" {
  description = "Unique reachable email for the read-only S3 state service user."
  type        = string
  default     = "ioanvictorstan+gitops-plan@gmail.com"

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.state_plan_user_email))
    error_message = "Use a unique reachable email or supported alias."
  }
}

locals {
  preview_environment = "${local.settings.github.environment}-plan"
  preview_subject     = "repo:${local.settings.github.repository}:environment:${local.preview_environment}"
  preview_condition = "all {${join(", ", [
    "request.principal.type = 'githubactions'",
    "request.principal.domain.id = '${local.identity_domain.id}'",
    "request.principal.name = '${local.preview_subject}'",
    "request.region = '${lower(local.settings.region_key)}'",
  ])}}"
}

resource "oci_identity_domains_app" "preview" {
  idcs_endpoint = local.identity_domain.url
  schemas = [
    "urn:ietf:params:scim:schemas:oracle:idcs:App",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
  ]
  display_name    = "${local.settings.name}-github-preview"
  active          = true
  is_oauth_client = true
  client_type     = "confidential"
  allowed_grants  = ["client_credentials"]
  based_on_template {
    value = "CustomWebAppTemplateId"
  }
}

resource "oci_identity_policy" "preview" {
  compartment_id = var.tenancy_ocid
  name           = "${local.settings.name}-github-preview"
  description    = "PR plans may inspect platform resources but cannot change them"
  statements = concat([
    "Allow any-user to inspect compartments in tenancy where ${local.preview_condition}",
    ], [for grant in [
      "read cluster-family", "read instance-family", "read virtual-network-family", "read volumes",
    ] : "Allow any-user to ${grant} in compartment id ${oci_identity_compartment.this["platform"].id} where ${local.preview_condition}"
  ])
}

resource "oci_identity_user" "preview" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-state-preview"
  description    = "Read-only S3 state access for PR plans"
  email          = var.state_plan_user_email
}

resource "oci_identity_group" "preview" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-state-preview"
  description    = "Read-only platform state"
}

resource "oci_identity_user_group_membership" "preview" {
  user_id  = oci_identity_user.preview.id
  group_id = oci_identity_group.preview.id
}

resource "oci_identity_policy" "preview_state" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-state-preview"
  description    = "Only inspect/read the platform state bucket; no locks or mutations"
  statements = [
    "Allow group ${oci_identity_group.preview.name} to read buckets in compartment id ${oci_identity_compartment.this["state"].id} where target.bucket.name = '${oci_objectstorage_bucket.this["state"].name}'",
    "Allow group ${oci_identity_group.preview.name} to read objects in compartment id ${oci_identity_compartment.this["state"].id} where target.bucket.name = '${oci_objectstorage_bucket.this["state"].name}'",
  ]
}

resource "oci_identity_customer_secret_key" "preview" {
  display_name = "platform-state-preview"
  user_id      = oci_identity_user.preview.id
}

resource "github_repository_environment" "preview" {
  repository  = github_repository_environment.oci.repository
  environment = local.preview_environment
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "preview" {
  repository     = github_repository_environment.preview.repository
  environment    = github_repository_environment.preview.environment
  branch_pattern = "refs/pull/*/merge"
}

resource "github_actions_environment_variable" "preview" {
  for_each = {
    OCI_TENANCY_OCID = var.tenancy_ocid
    OCI_NAMESPACE    = data.oci_objectstorage_namespace.this.namespace
    OCI_DOMAIN_URL   = local.identity_domain.url
  }
  repository    = github_repository_environment.preview.repository
  environment   = github_repository_environment.preview.environment
  variable_name = each.key
  value         = each.value
}

locals {
  preview_secrets = {
    OCI_CLIENT_ID        = oci_identity_domains_app.preview.name
    OCI_CLIENT_SECRET    = oci_identity_domains_app.preview.client_secret
    OCI_STATE_ACCESS_KEY = oci_identity_customer_secret_key.preview.id
    OCI_STATE_SECRET_KEY = oci_identity_customer_secret_key.preview.key
  }
}

resource "github_actions_environment_secret" "preview" {
  for_each    = nonsensitive(toset(keys(local.preview_secrets)))
  repository  = github_repository_environment.preview.repository
  environment = github_repository_environment.preview.environment
  secret_name = each.key
  value       = local.preview_secrets[each.key]
}
