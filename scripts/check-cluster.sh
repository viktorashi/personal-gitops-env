#!/usr/bin/env bash
set -euo pipefail
helm lint cluster/fns
helm template fns cluster/fns | kubeconform -strict -summary
helm template fns cluster/fns --set enabled=true,publicIp=192.0.2.1,acmeEmail=admin@example.com |
  kubeconform -strict -summary
helm template fns cluster/fns --set enabled=true,publicIp=192.0.2.1,acmeEmail=admin@example.com,publicAccess=true,registrationEnabled=false,adminUid=1 |
  kubeconform -strict -summary
if helm template fns cluster/fns --set enabled=true,publicIp=192.0.2.1,acmeEmail=admin@example.com,publicAccess=true >/dev/null 2>&1; then
  printf '%s\n' 'Unsafe public registration unexpectedly accepted' >&2
  exit 1
fi
# Argo CRs are checked against the matching installed CRDs on bootstrap.
kubectl kustomize cluster/argocd | kubeconform -strict -summary -ignore-missing-schemas
