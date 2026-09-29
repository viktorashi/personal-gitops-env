# OCI bootstrap

1. Copy [example inputs](foundation/inputs.example.tfvars) to
   `foundation/inputs.auto.tfvars` if it doesn't exist, and fill the placeholders.
2. `unupgraded_account_confirmed = true` means **not upgraded to Pay As You Go**.
   A free trial qualifies; this flag does **not** prevent trial-credit consumption.
3. From the repository root:

```sh
mise -E ops install
mise -E ops exec -- oci session authenticate --profile-name DEFAULT
mise exec -- tofu -chdir=infra/foundation init -lockfile=readonly
mise exec -- tofu -chdir=infra/foundation plan -out=bootstrap.tfplan
```

Stop at the plan: no resources provisioned. Zero-credit deployment is not yet
verified. Keep state and plan files private; back up state encrypted.

- Settings: [settings.json](settings.json).
- Human-owned: [foundation](foundation/), [recovery](recovery/).
- CI grants: [pipeline.tf](foundation/pipeline.tf); credential handoff:
  [outputs.tf](foundation/outputs.tf); deployment: [Platform workflow](../.github/workflows/platform.yml).
