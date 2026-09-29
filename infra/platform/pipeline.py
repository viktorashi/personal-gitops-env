"""GitHub's ephemeral OCI session and the platform-only plan boundary."""

import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parent
SETTINGS = json.loads((ROOT.parent / "settings.json").read_text())


def authenticate():
    os.umask(0o077)
    bootstrap = json.loads(os.environ["OCI_BOOTSTRAP"])
    session = Path(os.environ["RUNNER_TEMP"]) / "oci-session"
    session.mkdir(mode=0o700)
    key = session / "key.pem"
    subprocess.run(
        [
            "openssl",
            "genpkey",
            "-algorithm",
            "RSA",
            "-pkeyopt",
            "rsa_keygen_bits:2048",
            "-out",
            str(key),
        ],
        check=True,
        stderr=subprocess.DEVNULL,
    )
    public_key = subprocess.check_output(
        ["openssl", "pkey", "-in", str(key), "-pubout"], text=True
    )
    url = os.environ["ACTIONS_ID_TOKEN_REQUEST_URL"]
    url += "&" + urllib.parse.urlencode({"audience": SETTINGS["github"]["audience"]})
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": "Bearer " + os.environ["ACTIONS_ID_TOKEN_REQUEST_TOKEN"],
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        jwt = json.load(response)["value"]
    domain = bootstrap["domain_url"].rstrip("/")
    if not domain.startswith("https://"):
        raise ValueError("Identity Domain URL must use HTTPS")
    credentials = ":".join(
        urllib.parse.quote_plus(os.environ[name])
        for name in ("OCI_CLIENT_ID", "OCI_CLIENT_SECRET")
    )
    request = urllib.request.Request(
        domain + "/oauth2/v1/token",
        data=urllib.parse.urlencode(
            {
                "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
                "requested_token_type": "urn:oci:token-type:oci-rpst",
                "subject_token_type": "jwt",
                "subject_token": jwt,
                "public_key": public_key,
                "res_type": "githubactions",
                "rpst_exp": 60,
            }
        ).encode(),
        headers={
            "Authorization": "Basic " + base64.b64encode(credentials.encode()).decode()
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        token = json.load(response)["token"]
    (session / "token").write_text(token)
    config = session / "config"
    config.write_text(
        f"[DEFAULT]\ntenancy={bootstrap['tenancy_id']}\nregion={SETTINGS['region']}\n"
        f"key_file={key}\nsecurity_token_file={session / 'token'}\n"
    )
    with open(os.environ["GITHUB_ENV"], "a") as environment:
        environment.write(f"OCI_CONFIG_FILE={config}\nOCI_CLI_CONFIG_FILE={config}\n")
    (ROOT / "foundation.auto.tfvars.json").write_text(
        json.dumps(bootstrap["platform_inputs"])
    )
    (ROOT / "backend.local.hcl").write_text(
        "\n".join(
            f"{name} = {json.dumps(value)}"
            for name, value in bootstrap["backend"].items()
        )
        + "\n"
    )


def check_plan(plan):
    expected = {
        "oci_containerengine_cluster.this",
        "oci_containerengine_node_pool.this",
    }
    seen = set()
    for change in plan.get("resource_changes", []):
        if change.get("mode") == "data":
            continue
        address = change["address"]
        if address not in expected:
            raise ValueError(f"Unexpected managed resource: {address}")
        seen.add(address)
        if "delete" in change["change"]["actions"]:
            raise ValueError(f"Deletion/replacement forbidden: {address}")
        after = change["change"]["after"]
        if address == "oci_containerengine_cluster.this":
            if after.get("type") != "BASIC_CLUSTER":
                raise ValueError("Only a Basic cluster is permitted")
        else:
            node = SETTINGS["node"]
            shape = after["node_shape_config"][0]
            pool = after["node_config_details"][0]
            source = after["node_source_details"][0]
            if not (
                after["node_shape"] == node["shape"]
                and shape["ocpus"] == node["ocpus"] <= 2
                and shape["memory_in_gbs"] == node["memory_gbs"] <= 12
                and pool["size"] == 1
                and int(source["boot_volume_size_in_gbs"]) == node["boot_gbs"] == 50
            ):
                raise ValueError(
                    "Node pool exceeds the agreed free-resource configuration"
                )
    if seen != expected:
        raise ValueError("Plan must contain exactly the platform cluster and node pool")
    print("Platform-only plan and resource sizing verified")


if __name__ == "__main__":
    if sys.argv[1:] == ["auth"]:
        authenticate()
    elif sys.argv[1:] == ["check-plan"]:
        check_plan(json.load(sys.stdin))
    else:
        raise SystemExit("Usage: pipeline.py auth|check-plan")
