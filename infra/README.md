# OCI bootstrap

With a valid OCI session, run from the repository root:

```sh
export GITHUB_TOKEN="$(gh auth token)"
mise exec -- tofu -chdir=infra/foundation init -lockfile=readonly
```

Copy [example inputs](foundation/inputs.example.tfvars) to `inputs.auto.tfvars`
in that directory. Set your allowed public IPv4 `/32`, confirm no paid upgrade,
and set `state_user_email` to a reachable address unique among tenancy users
(a plus-address alias works if your email provider supports it).
Remove obsolete placeholders from existing files; they override `TF_VAR_*`.

```sh
mise exec -- tofu -chdir=infra/foundation plan -out=bootstrap.tfplan
```

[Data sources](foundation/data.tf) resolve AD-1 and the `Default` domain during plan;
[variables](foundation/variables.tf) expose selection and authentication options.
[mise's local bridge](../scripts/oci-env.sh) reads the tenancy from your profile,
so activated shells can use `tofu plan`; otherwise `mise exec -- tofu plan`.
Select a profile with `TF_VAR_profile` (or `OCI_CLI_PROFILE`) before invoking mise;
explicit `TF_VAR_tenancy_ocid` wins. CI never reads local profiles.
Renew expired or missing sessions with `mise run oci-login`.

Stop before apply: [Always Free audit](free-tier.md) has unresolved eligibility checks.
Keep state private.
Settings: [settings.json](settings.json). Permissions: [pipeline.tf](foundation/pipeline.tf).

Foundation owns [GitHub settings and secrets](foundation/github.tf).
Its private state contains the secrets. Import existing GitHub resources first.
Downstream stacks use [live discovery](modules/foundation-data/main.tf) during plan.
No exported tfvars or backend configuration files are used.

Python dependencies and build tools: [pyproject.toml](../pyproject.toml), [uv.lock](../uv.lock).
Build with `mise run package-backup`; recovery rejects stale artifacts.
The recovery runtime version is pinned in [settings.json](settings.json).

After platform creation: [Argo/FNS bootstrap](../cluster/README.md).
Networking uses separate public OKE/API-LB and worker subnets, plus private Functions.
Their separate internet/service routes follow [Oracle's requirements](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengnetworkconfig.htm).
OKE rejects node pools in the cluster's service load-balancer subnet.
State, recovery and platform compartments retain their separate IAM boundaries.
