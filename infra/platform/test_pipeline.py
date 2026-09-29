import copy
import unittest

from pipeline import check_plan


class PlanBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.plan = {
            "resource_changes": [
                {
                    "address": "oci_containerengine_cluster.this",
                    "mode": "managed",
                    "change": {
                        "actions": ["create"],
                        "after": {"type": "BASIC_CLUSTER"},
                    },
                },
                {
                    "address": "oci_containerengine_node_pool.this",
                    "mode": "managed",
                    "change": {
                        "actions": ["create"],
                        "after": {
                            "node_shape": "VM.Standard.A1.Flex",
                            "node_shape_config": [{"ocpus": 2, "memory_in_gbs": 12}],
                            "node_config_details": [{"size": 1}],
                            "node_source_details": [{"boot_volume_size_in_gbs": "50"}],
                        },
                    },
                },
            ]
        }

    def test_expected_platform(self):
        check_plan(self.plan)

    def test_unexpected_resource(self):
        extra = copy.deepcopy(self.plan["resource_changes"][0])
        extra["address"] = "oci_identity_policy.escalation"
        self.plan["resource_changes"].append(extra)
        with self.assertRaises(ValueError):
            check_plan(self.plan)

    def test_replacement(self):
        self.plan["resource_changes"][1]["change"]["actions"] = ["delete", "create"]
        with self.assertRaises(ValueError):
            check_plan(self.plan)

    def test_enhanced_cluster(self):
        self.plan["resource_changes"][0]["change"]["after"]["type"] = "ENHANCED_CLUSTER"
        with self.assertRaises(ValueError):
            check_plan(self.plan)

    def test_oversized_pool(self):
        self.plan["resource_changes"][1]["change"]["after"]["node_config_details"][0][
            "size"
        ] = 2
        with self.assertRaises(ValueError):
            check_plan(self.plan)

    def test_missing_resource(self):
        self.plan["resource_changes"].pop()
        with self.assertRaises(ValueError):
            check_plan(self.plan)


if __name__ == "__main__":
    unittest.main()
