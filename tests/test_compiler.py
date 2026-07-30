from __future__ import annotations

import unittest

from diegetic_travel.compiler import build_dialogue_manifest, compile_runtime


def fixture_graph() -> dict[str, object]:
    return {
        "meta": {"name": "test", "version": 1, "generated_against": "fixture"},
        "rules": {
            "base_cost": 50,
            "hazard_cost": 100,
            "ferry_immune_to_war_multiplier": True,
            "war_multiplier": {
                "early": 2,
                "active": 3,
                "resolved": 1,
                "quests": {
                    "CW01A": "Skyrim.esm|0x0D517A",
                    "CW01B": "Skyrim.esm|0x0E2D29",
                    "CWResolution01": "Skyrim.esm|0x02B272",
                },
            },
            "time": {"speed_units_per_hour": 100.0},
        },
        "nodes": {
            "a": {
                "name": "A",
                "type": "capital",
                "providers": ["carriage", "ferry"],
                "condition": None,
                "marker": "Skyrim.esm|0x000001",
                "pos": [0.0, 0.0],
            },
            "gate": {
                "name": "Gate",
                "type": "hazard",
                "providers": [],
                "condition": None,
                "marker": "Skyrim.esm|0x000002",
                "pos": [100.0, 0.0],
                "hazard": "gate",
            },
            "b": {
                "name": "B",
                "type": "capital",
                "providers": ["carriage", "ferry"],
                "condition": None,
                "marker": "Skyrim.esm|0x000003",
                "pos": [200.0, 0.0],
            },
            "detour": {
                "name": "Detour",
                "type": "town",
                "providers": ["carriage"],
                "condition": None,
                "marker": "Skyrim.esm|0x000004",
                "pos": [100.0, 100.0],
            },
        },
        "hazards": {
            "gate": {
                "name": "Gate",
                "class": "bandit",
                "mult": 2,
                "role": "chokepoint",
                "location": "Skyrim.esm|0x000101",
                "marker": "Skyrim.esm|0x000002",
                "pos": [100.0, 0.0],
            }
        },
        "edges": [
            {
                "a": "a",
                "b": "gate",
                "weight": 0.5,
                "provider": "carriage",
                "hazards": [],
                "confidence": "high",
            },
            {
                "a": "gate",
                "b": "b",
                "weight": 0.5,
                "provider": "carriage",
                "hazards": [],
                "confidence": "high",
            },
            {
                "a": "a",
                "b": "detour",
                "weight": 1.0,
                "provider": "carriage",
                "hazards": [],
                "confidence": "high",
            },
            {
                "a": "detour",
                "b": "b",
                "weight": 1.0,
                "provider": "carriage",
                "hazards": [],
                "confidence": "high",
            },
            {
                "a": "a",
                "b": "b",
                "weight": 0.1,
                "provider": "ferry",
                "hazards": [],
                "confidence": "high",
            },
        ],
    }


class CompilerTests(unittest.TestCase):
    def test_carriage_routes_do_not_borrow_ferry_edges(self) -> None:
        runtime, report = compile_runtime(fixture_graph())
        route = runtime["providers"]["carriage"]["routes"]["aTob"]
        first = route["candidates"][0]
        self.assertEqual(1.0, first["base_units"])
        self.assertEqual(["a", "gate", "b"], first["path"])
        self.assertEqual(1, report["providers"]["carriage"]["ignored_other_provider_edges"])

    def test_chokepoint_hazard_is_collected_from_path_node(self) -> None:
        runtime, _ = compile_runtime(fixture_graph())
        route = runtime["providers"]["carriage"]["routes"]["aTob"]
        self.assertEqual(["gate"], route["candidates"][0]["hazards"])

    def test_form_references_are_emitted_for_jcontainers(self) -> None:
        runtime, _ = compile_runtime(fixture_graph())
        self.assertEqual(
            "__formData|Skyrim.esm|0x000101",
            runtime["hazards"]["gate"]["location"],
        )

    def test_sensor_overrides_supply_activation_reference(self) -> None:
        graph = fixture_graph()
        graph["hazards"]["mound"] = {
            "name": "Mound",
            "class": "dragon_mound",
            "mult": 2,
            "role": "proximity",
            "location": None,
            "marker": None,
            "pos": [10_000.0, 10_000.0],
        }
        runtime, _ = compile_runtime(
            graph,
            sensor_overrides={
                "hazards": {
                    "mound": {
                        "activation_ref": "Skyrim.esm|0x0FDB35",
                        "clears_on_death": True,
                    }
                }
            },
        )
        self.assertEqual(
            "__formData|Skyrim.esm|0x0FDB35",
            runtime["hazards"]["mound"]["activation_ref"],
        )
        self.assertTrue(runtime["hazards"]["mound"]["clears_on_death"])

    def test_verified_actor_death_is_a_valid_cleared_sensor(self) -> None:
        graph = fixture_graph()
        graph["hazards"]["mound"] = {
            "name": "Mound",
            "class": "dragon_mound",
            "mult": 2,
            "role": "proximity",
            "location": None,
            "activation_ref": "Skyrim.esm|0x000102",
            "clears_on_death": True,
            "marker": None,
            "pos": [100.0, 0.0],
        }
        graph["edges"][0]["hazards"] = ["mound"]

        _, report = compile_runtime(graph)

        self.assertEqual([], report["providers"]["carriage"]["sensor_issues"])

    def test_dialogue_globals_are_shared_per_destination(self) -> None:
        runtime, _ = compile_runtime(fixture_graph())
        manifest = build_dialogue_manifest(
            runtime,
            {
                "quest": "CFTO.esp|0x00AA02",
                "destination_global": "CFTO.esp|0x0A7B36",
                "free_faction": "CFTO.esp|0x0DA68B",
                "origins": {
                    "a": {"driver": "CFTO.esp|0x000001"},
                    "b": {"driver": "CFTO.esp|0x000002"},
                },
                "destinations": {"a": 1, "b": 2, "detour": 3},
                "dialogue": {
                    "branch": "CFTO.esp|0x000010",
                    "root_topic": "CFTO.esp|0x000011",
                    "root_info": "CFTO.esp|0x000012",
                    "free_root_info": "CFTO.esp|0x000013",
                    "destinations": {
                        "a": {
                            "topic": "CFTO.esp|0x000020",
                            "success_info": "CFTO.esp|0x000021",
                            "failure_info": "CFTO.esp|0x000022",
                        },
                        "b": {
                            "topic": "CFTO.esp|0x000030",
                            "success_info": "CFTO.esp|0x000031",
                            "failure_info": "CFTO.esp|0x000032",
                        },
                        "detour": {
                            "topic": "CFTO.esp|0x000040",
                            "success_info": "CFTO.esp|0x000041",
                            "failure_info": "CFTO.esp|0x000042",
                        },
                    },
                },
                "custom_destinations": {},
            },
        )
        self.assertEqual(
            manifest["origins"]["a"]["entries"][0]["globals"]["cost"],
            manifest["globals"]["b"]["cost"],
        )


if __name__ == "__main__":
    unittest.main()
