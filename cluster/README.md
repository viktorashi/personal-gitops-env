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

## Public address and first user

Endpoint: <https://fns-141-147-0-172.sslip.io>.
[sslip.io](https://sslip.io/) resolves the embedded load-balancer IP for free;
it is an external DNS dependency, not a domain we own.

The OCI load balancer terminates TLS; no extra proxy is installed.
Trust [notes-ca.crt](notes-ca.crt) on each personal device before logging in.
This is a private CA, **not** a publicly trusted certificate. Never disable TLS
verification or accept an unexplained certificate warning. Its private key stays
in the protected human bootstrap state. Verify the public certificate fingerprint
with `openssl x509 -in cluster/notes-ca.crt -noout -fingerprint -sha256`.

The initial account is `viktorashi`; its generated password is in the ignored,
mode-0600 `.local/fns-login.json` on the bootstrap machine. Move it to your password
manager and change it after first login. Registration is now disabled.
In Obsidian, install Fast Note Sync, then paste the API configuration copied from
the server's authenticated web UI. Test a disposable vault before real notes.
Keep an independent encrypted copy of your vault; sync is not a backup.

For a fresh first-user bootstrap, keep `publicAccess: false`, merge, then run:

```sh
kubectl -n fns port-forward deployment/fns 9000:9000
```

Register at `http://localhost:9000`. Commit your numeric user ID as `adminUid`,
with `registrationEnabled: false` and `publicAccess: true`.
The public listener is HTTPS-only; traffic inside the VCN goes to FNS over HTTP.
While `publicAccess` is false, the Service selects no pods.

The server certificate lasts one year.
Reconcile [the TLS resources](../infra/cluster/tls.tf)
in the last 30 days to renew it, then verify the load balancer presents the new
certificate. This setup does not renew itself while OpenTofu is idle.
An IP change requires a Git hostname update and a matching certificate.

Secrets, SQLite and attachments share the backed-up volume.
Startup rewrites config.yaml from Git settings.
Reverts restore manifests, **not data**. Test SQLite/attachment recovery before
storing irreplaceable notes. Stop Argo reconciliation and FNS for volume recovery.

## Checks

`mise run check-cluster` checks disabled/setup/public manifests.
After deployment, change the Deployment's replica count and verify self-healing.
Verify an Obsidian round-trip. These live checks need OKE.
