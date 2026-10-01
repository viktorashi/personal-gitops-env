provider "github" {
  owner = split("/", local.settings.github.repository)[0]
}

resource "github_repository_ruleset" "main" {
  repository  = split("/", local.settings.github.repository)[1]
  name        = "main requires PR and CI"
  target      = "branch"
  enforcement = "active"

  # No bypass actors, including repository administrators.
  conditions {
    ref_name {
      include = ["refs/heads/${local.settings.github.branch}"]
      exclude = []
    }
  }
  rules {
    deletion         = true
    non_fast_forward = true
    pull_request {
      # A solo maintainer cannot approve their own PR.
      required_approving_review_count = 0
    }
    required_status_checks {
      strict_required_status_checks_policy = true
      required_check {
        context        = "validate"
        integration_id = 15368 # GitHub Actions
      }
    }
  }
}

resource "github_repository_environment" "oci" {
  repository  = split("/", local.settings.github.repository)[1]
  environment = local.settings.github.environment
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "main" {
  repository     = github_repository_environment.oci.repository
  environment    = github_repository_environment.oci.environment
  branch_pattern = local.settings.github.branch
}

resource "oci_identity_customer_secret_key" "state" {
  display_name = "platform-state"
  user_id      = oci_identity_user.state.id
}

resource "github_actions_environment_variable" "this" {
  for_each = {
    OCI_TENANCY_OCID = var.tenancy_ocid
    OCI_NAMESPACE    = data.oci_objectstorage_namespace.this.namespace
    OCI_DOMAIN_URL   = local.identity_domain.url
  }
  repository    = github_repository_environment.oci.repository
  environment   = github_repository_environment.oci.environment
  variable_name = each.key
  value         = each.value
}

locals {
  github_secrets = {
    OCI_CLIENT_ID        = oci_identity_domains_app.github.name
    OCI_CLIENT_SECRET    = oci_identity_domains_app.github.client_secret
    OCI_STATE_ACCESS_KEY = oci_identity_customer_secret_key.state.id
    OCI_STATE_SECRET_KEY = oci_identity_customer_secret_key.state.key
  }
}

resource "github_actions_environment_secret" "this" {
  for_each    = nonsensitive(toset(keys(local.github_secrets)))
  repository  = github_repository_environment.oci.repository
  environment = github_repository_environment.oci.environment
  secret_name = each.key
  value       = local.github_secrets[each.key]
}
