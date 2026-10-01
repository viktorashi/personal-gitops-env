# Notes GitOps

This is the environment repo from the [book's quickstart](https://github.com/gitops-tech/book):
Upstream builds FNS; Argo reconciles this repo's images/configuration inside OKE.
[Argo CD's Helm chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
provides the controllers and API/UI server. SSO and notifications are disabled;
ApplicationSet has zero replicas. Both Argo and FNS are rendered by Helm.
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
4. `helm dependency build cluster/argocd`
5. Render and bootstrap (on a fresh cluster, repeat after CRDs are established if
   Kubernetes initially cannot discover Application/AppProject):

   ```sh
    helm template argocd cluster/argocd -n argocd | \
      kubectl apply --server-side -f -
   ```

6. Wait for the application CRDs:

   ```sh
   kubectl wait --for=condition=Established --timeout=120s \
     crd/applications.argoproj.io crd/appprojects.argoproj.io
   ```

7. Repeat the render/apply command, then `kubectl -n argocd get applications`.

The public repo needs no Git credential. Namespaces and retained volume bindings
belong to [the human bootstrap stack](../infra/cluster/main.tf).
Argo owns application resources.
Keep that local state with your other encrypted bootstrap-state backups.

### Existing raw-manifest installation → Helm

The upstream chart adds immutable selectors to the controller and repo server.
Before merging this migration, pause the `argocd` Application's automated sync.
With the reviewed chart checked out, delete only these stateless Argo workloads:

```sh
kubectl -n argocd patch application argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
kubectl -n argocd delete statefulset argocd-application-controller
kubectl -n argocd delete deployment argocd-repo-server
```

Then merge the checked PR, check out the merged `main`, and run the dependency
build and render/apply commands above. Do not restart reconciliation against the
old `main`: it still contains the raw manifests.
Do not run this deletion on subsequent reconciliations. FNS keeps running.
Verify both Applications are Synced/Healthy after the migration.
Helm is the renderer; Argo owns reconciliation, not a separate Helm release.

## Argo CD web UI

With the OKE kubeconfig and `OCI_CLI_AUTH=security_token` set:

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open <https://localhost:8080>. The server uses its own self-signed certificate;
the port-forward is localhost-only over the authenticated Kubernetes connection.
Sign in as `admin`, retrieving the generated initial password locally:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode
```

Change the password in User Info, then delete `argocd-initial-admin-secret`.
The UI Service is internal; it creates no public load balancer.

## Public address and first user

### Public certificate migration (pending network access)

`publicTls.enabled` in [FNS values](fns/values.yaml) stages the replacement:
the pinned Traefik Helm dependency obtains and renews a Let's Encrypt certificate
using TLS-ALPN-01 on port 443. It uses the existing load balancer as a TCP
forwarder and stores its ACME account/certificates in `tls-acme` on `fns-data`.
No additional load balancer, disk, DNS account or certificate controller is needed.
The router has no Kubernetes API permissions. Its public dashboard is disabled.

After Argo's Helm migration, enable that value through a PR. Keep the existing
`fns` Service (and its IP); verify the OCI listener becomes TCP, issuance succeeds,
and HTTPS validates without `notes-ca.crt` before removing the old TLS resources.
The first issuance may briefly serve Traefik's fallback certificate: do not bypass
verification. Until the public certificate is verified, the private-CA setup below
remains the deployed configuration.

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
