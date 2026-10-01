# Deployment

[Validate](../.github/workflows/check.yml) runs checks, then calls
[Platform](../.github/workflows/platform.yml) for a read-only PR plan and an updated
`diff` comment. Both `validate` and `plan` must pass before merge. The merged
commit is checked again, replanned against current state, and applied automatically.
Argo pulls application changes from `main`; CI does not publish container images.

## One-time authentication

Use `gh auth login` and `mise run oci-login` locally. Then run the
[foundation bootstrap](../infra/README.md) with `GITHUB_TOKEN="$(gh auth token)"`.
Set `state_plan_user_email` to a second unique reachable address (or an alias your
mail provider supports). Foundation creates the identities and uploads their
credentials directly to GitHub environments; no copying secrets into the UI.

| Identity | Capabilities |
| --- | --- |
| Validation job | Repository read; no cloud credentials |
| `oci-plan` federated principal | Read platform metadata; PR events only |
| Preview state user | Read state bucket; no state/lock writes |
| `oci` federated principal | Change platform compute; main only; no IAM or recovery administration |
| Deployment state user | State bucket reads/writes and lock operations |
| Backup Function | Source-volume backups and recovery catalog |
| Human foundation session | IAM, quotas, credentials, GitHub policy |

Both state users support Customer Secret Keys only: console passwords, API keys,
auth tokens and SMTP credentials are disabled. Cloud identities use GitHub OIDC
and separate non-admin OAuth clients; these are not human OCI accounts.
Foundation state contains their secrets and must remain private and backed up.

PR previews use no state lock because their credentials cannot write. Deployment
locks state and creates a fresh plan, rather than applying a stale PR preview.
Fork PRs run credential-free checks but cannot pass the cloud-plan gate; review
and move accepted changes to a repository branch. No `pull_request_target` runs
untrusted code with deployment credentials.

The initial [cluster bootstrap](../cluster/README.md) still requires the human
session. Thereafter Argo continuously reconciles FNS. Foundation and recovery
administration remain outside the platform deployment identity.
