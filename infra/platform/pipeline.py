"""Check the whole platform plan, including unexpected resources and deletions."""

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
SETTINGS = json.loads((ROOT.parent / "settings.json").read_text())


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
    check_plan(json.load(sys.stdin))
