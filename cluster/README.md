# Notes GitOps

This is the environment repo from the [book's quickstart](https://github.com/gitops-tech/book):
Upstream builds FNS; Argo reconciles this repo's images/configuration inside OKE.
[Argo CD Core](https://argo-cd.readthedocs.io/en/stable/operator-manual/core/) omits the
public UI, SSO and notifications; the unused ApplicationSet controller is removed.
CI only validates manifests.

## Bootstrap once

After foundation and platform apply, create an OKE kubeconfig using
the platform's `cluster_id` output:

```sh
oci ce cluster create-kubeconfig --cluster-id <cluster_id> \
  --file <private-path> --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT --auth security_token
export KUBECONFIG=<private-path> OCI_CLI_AUTH=security_token
```

1. `tofu -chdir=infra/cluster init -lockfile=readonly`
2. Plan, review, then apply the saved plan:

   ```sh
   tofu -chdir=infra/cluster plan -var="kubeconfig=$KUBECONFIG" \
     -out=bootstrap.tfplan
   ```

3. Commit/push this configuration before bootstrap; Argo reads `main` on GitHub.
4. `kubectl apply --server-side -k cluster/argocd/install`
5. Wait for the application CRDs:

   ```sh
   kubectl wait --for=condition=Established --timeout=120s \
     crd/applications.argoproj.io crd/appprojects.argoproj.io
   ```

6. `kubectl apply --server-side -k cluster/argocd`
7. `kubectl -n argocd get applications` and `kubectl -n fns get svc fns`.

The public repo needs no Git credential. Namespaces and retained volume bindings
belong to [the human bootstrap stack](../infra/cluster/main.tf).
Argo owns application resources.
Keep that local state with your other encrypted bootstrap-state backups.

## DNS and first user

Create a DNS A record pointing your hostname at the Service's public IP.
Set `hostname` and `enabled: true` in [values.yaml](fns/values.yaml).
Keep `publicAccess: false`, merge, then run:

```sh
kubectl -n fns port-forward deployment/fns 9000:9000
```

Register at `http://localhost:9000`. Commit your numeric user ID as `adminUid`,
with `registrationEnabled: false` and `publicAccess: true`.
The load balancer forwards HTTP port 80 directly to FNS on port 9000.
DNS supplies the name, not encryption: this configuration has no HTTPS.
Use `http://<hostname>` for the API. While `publicAccess` is false, the public
Service selects no pods; initial registration is accessible only by port-forward.

Secrets, SQLite and attachments share the backed-up volume.
Startup rewrites config.yaml from Git settings.
Reverts restore manifests, **not data**. Test SQLite/attachment recovery before
storing irreplaceable notes. Stop Argo reconciliation and FNS for volume recovery.

## Checks

`mise run check-cluster` checks disabled/setup/public manifests.
After deployment, change the Deployment's replica count and verify self-healing.
Verify an Obsidian round-trip. These live checks need OKE.
