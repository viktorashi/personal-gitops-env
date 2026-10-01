# Only the human foundation identity owns this trust and its grants.
locals {
  # Explicit GitHub subject template avoids name-based versus immutable-default drift.
  github_subject_prefix = "repository_owner_id:${local.settings.github.owner_id}:repository_id:${local.settings.github.repository_id}:environment"
  github_subject        = "${local.github_subject_prefix}:${local.settings.github.environment}"
  github_claims = {
    repository_id       = local.settings.github.repository_id
    repository_owner_id = local.settings.github.owner_id
    aud                 = local.settings.github.audience
  }
  github_conditions = [
    "request.principal.type = 'identityfederateddomainapp'",
    "request.principal.domain.id = '${local.identity_domain.id}'",
    "request.principal.name = '${local.github_subject}'",
    "request.region = '${lower(local.settings.region_key)}'",
  ]
  github_condition = "all {${join(", ", local.github_conditions)}}"

  # OCI's CreateCluster/CreateNodePool prerequisite grants are compartment-scoped.
  # This is an infrastructure deployer: it can replace compute and affect live data.
  # No IAM, quotas, Functions, backup administration, or source-volume deletion grant.
  github_protected_grants = {
    "manage clusters"           = ["request.permission != 'CLUSTER_DELETE'", "request.permission != 'CLUSTER_MANAGE'"]
    "manage cluster-node-pools" = ["request.permission != 'CLUSTER_NODE_POOL_DELETE'"]
  }
}

resource "oci_identity_domains_app" "github" {
  idcs_endpoint = local.identity_domain.url
  schemas = [
    "urn:ietf:params:scim:schemas:oracle:idcs:App",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
  ]
  display_name    = "${local.settings.name}-github-exchange"
  active          = true
  is_oauth_client = true
  client_type     = "confidential"
  allowed_grants  = ["client_credentials"]
  based_on_template {
    value = "CustomWebAppTemplateId"
  }
}

resource "oci_identity_domains_identity_propagation_trust" "github" {
  idcs_endpoint          = local.identity_domain.url
  schemas                = ["urn:ietf:params:scim:schemas:oracle:idcs:IdentityPropagationTrust"]
  name                   = "${local.settings.name}-github"
  type                   = "JWT"
  active                 = true
  issuer                 = "https://token.actions.githubusercontent.com"
  public_key_endpoint    = "https://token.actions.githubusercontent.com/.well-known/jwks"
  subject_type           = "Resource"
  subject_claim_name     = "sub"
  allow_impersonation    = true
  impersonating_resource = "githubactions"
  # OCI permits one trust per issuer. Signed environment subjects select IAM grants;
  # GitHub deployment policies restrict which refs may use those environments.
  oauth_clients = [oci_identity_domains_app.github.name, oci_identity_domains_app.preview.name]
  dynamic "claim_validations" {
    for_each = local.github_claims
    content {
      name  = claim_validations.key
      value = claim_validations.value
    }
  }
}

resource "oci_identity_policy" "github" {
  compartment_id = var.tenancy_ocid
  name           = "${local.settings.name}-github-platform"
  description    = "Federated main-branch platform deployer; no tenancy administration or recovery-plane grants"
  statements = concat([
    "Allow any-user to inspect compartments in tenancy where ${local.github_condition}",
    ], [for grant, restrictions in local.github_protected_grants :
    "Allow any-user to ${grant} in compartment id ${oci_identity_compartment.this["platform"].id} where all {${join(", ", concat(local.github_conditions, restrictions))}}"
    ], [for grant in [
      "read cluster-work-requests", "manage instance-family", "read virtual-network-family", "read volumes",
      "use subnets", "use vnics", "use network-security-groups", "use private-ips", "manage public-ips",
    ] : "Allow any-user to ${grant} in compartment id ${oci_identity_compartment.this["platform"].id} where ${local.github_condition}"
  ])
}
