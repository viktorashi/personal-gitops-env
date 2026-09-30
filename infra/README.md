# OCI bootstrap

With a valid OCI session, run from the repository root:

```sh
TF_VAR_tenancy_ocid="$(mise -E ops exec -- oci iam availability-domain list \
  --auth security_token --query 'data[0]."compartment-id"' --raw-output)"
export TF_VAR_tenancy_ocid
mise exec -- tofu -chdir=infra/foundation init -lockfile=readonly
```

Copy [example inputs](foundation/inputs.example.tfvars) to `inputs.auto.tfvars`
in that directory. Set your allowed public IPv4 `/32` and confirm no paid upgrade.

```sh
mise exec -- tofu -chdir=infra/foundation plan -out=bootstrap.tfplan
```

[Data sources](foundation/data.tf) resolve AD-1 and the `Default` domain during plan;
[variables](foundation/variables.tf) expose selection and authentication options.
The OCI provider requires a tenancy input; the CLI above gets it from your profile.
Renew expired sessions with
`mise -E ops exec -- oci session authenticate --profile-name DEFAULT`.

Stop before apply: zero trial-credit usage is not yet verified. Keep state private.
Settings: [settings.json](settings.json). Permissions: [pipeline.tf](foundation/pipeline.tf).
