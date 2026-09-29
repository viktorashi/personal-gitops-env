# Only the human foundation identity owns this trust and its grants.
locals {
  github_subject = "repo:${local.settings.github.repository}:environment:${local.settings.github.environment}"
  github_claims = {
    repository_id       = local.settings.github.repository_id
    repository_owner_id = local.settings.github.owner_id
    sub                 = local.github_subject
    ref                 = "refs/heads/${local.settings.github.branch}"
    aud                 = local.settings.github.audience
  }
  github_conditions = [
    "request.principal.type = 'githubactions'",
    "request.principal.domain.id = '${var.identity_domain.id}'",
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
  idcs_endpoint   = var.identity_domain.url
  schemas         = ["urn:ietf:params:scim:schemas:oracle:idcs:App"]
  display_name    = "${local.settings.name}-github-exchange"
  active          = true
  is_oauth_client = true
  client_type     = "confidential"
  allowed_grants  = ["client_credentials"]
  based_on_template {
    value = var.identity_domain.oauth_template_id
  }
}

resource "oci_identity_domains_identity_propagation_trust" "github" {
  idcs_endpoint          = var.identity_domain.url
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
  oauth_clients          = [oci_identity_domains_app.github.name]
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
      "read cluster-work-requests", "manage instance-family", "read virtual-network-family",
      "use subnets", "use vnics", "use network-security-groups", "use private-ips", "manage public-ips",
    ] : "Allow any-user to ${grant} in compartment id ${oci_identity_compartment.this["platform"].id} where ${local.github_condition}"
  ])
}
