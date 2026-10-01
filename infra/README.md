# OCI bootstrap

With a valid OCI session, run from the repository root:

```sh
TF_VAR_tenancy_ocid="$(mise exec -- oci iam availability-domain list \
  --auth security_token --query 'data[0]."compartment-id"' --raw-output)"
export TF_VAR_tenancy_ocid
export GITHUB_TOKEN="$(gh auth token)"
mise exec -- tofu -chdir=infra/foundation init -lockfile=readonly
```

Copy [example inputs](foundation/inputs.example.tfvars) to `inputs.auto.tfvars`
in that directory. Set your allowed public IPv4 `/32` and confirm no paid upgrade.
Existing files should contain only those inputs; old placeholders override `TF_VAR_*`.

```sh
mise exec -- tofu -chdir=infra/foundation plan -out=bootstrap.tfplan
```

[Data sources](foundation/data.tf) resolve AD-1 and the `Default` domain during plan;
[variables](foundation/variables.tf) expose selection and authentication options.
The OCI provider requires a tenancy input; the CLI above gets it from your profile.
Renew expired sessions with
`mise exec -- oci session authenticate --profile-name DEFAULT`.

Stop before apply: zero trial-credit usage is not yet verified. Keep state private.
Settings: [settings.json](settings.json). Permissions: [pipeline.tf](foundation/pipeline.tf).

Foundation owns [GitHub settings and secrets](foundation/github.tf).
Its private state contains the secrets. Import existing GitHub resources first.
Downstream stacks use [live discovery](modules/foundation-data/main.tf) during plan.
No exported tfvars or backend configuration files are used.

Python dependencies and build tools: [pyproject.toml](../pyproject.toml), [uv.lock](../uv.lock).
Build with `mise run package-backup`; recovery rejects stale artifacts.
The [recovery runtime](recovery/variables.tf) requires an explicit version OCID until
an authenticated lookup can supply a reviewed pin. No `latest` fallback is used.
