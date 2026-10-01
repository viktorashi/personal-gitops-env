#!/usr/bin/env bash
# Sourced by mise; CI supplies its own identity and inputs.
if [[ -n ${CI:-} || ${TF_VAR_auth:-SecurityToken} != SecurityToken ]]; then
  return 0
fi

export TF_VAR_profile="${TF_VAR_profile:-${OCI_CLI_PROFILE:-DEFAULT}}"
export OCI_CONFIG_FILE="${OCI_CONFIG_FILE:-${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}}"
if [[ -z ${TF_VAR_tenancy_ocid:-} && -r $OCI_CONFIG_FILE ]]; then
  tenancy=$(
    python - <<'PY'
import configparser
import os

config = configparser.ConfigParser(interpolation=None)
config.read(os.environ["OCI_CONFIG_FILE"])
profile = os.environ["TF_VAR_profile"]
if profile in config:
    print(config[profile].get("tenancy", "").strip())
PY
  ) || return 1
  if [[ -n $tenancy ]]; then
    export TF_VAR_tenancy_ocid="$tenancy"
  fi
  unset tenancy
fi
