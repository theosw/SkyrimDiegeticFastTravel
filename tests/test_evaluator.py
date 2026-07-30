from __future__ import annotations

import unittest

from diegetic_travel.compiler import compile_runtime
from diegetic_travel.evaluator import (
    HazardObservation,
    WarStage,
    quote_route,
)
from test_compiler import fixture_graph


class EvaluatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.runtime, _ = compile_runtime(fixture_graph())

    def test_active_refuse_tier_chokepoint_selects_detour(self) -> None:
        quote = quote_route(
            self.runtime,
            "aTob",
            {"gate": HazardObservation(cleared=False)},
        )
        self.assertTrue(quote.available)
        self.assertEqual(("a", "detour", "b"), quote.path)
        self.assertEqual(200, quote.fare)
        self.assertEqual(1, quote.blocked_candidates)

    def test_cleared_chokepoint_selects_short_route(self) -> None:
        quote = quote_route(
            self.runtime,
            "aTob",
            {"gate": HazardObservation(cleared=True)},
        )
        self.assertEqual(("a", "gate", "b"), quote.path)
        self.assertEqual(100, quote.fare)

    def test_resolved_war_uses_base_multiplier(self) -> None:
        quote = quote_route(
            self.runtime,
            "aTob",
            {"gate": HazardObservation(cleared=True)},
            WarStage.RESOLVED,
        )
        self.assertEqual(50, quote.fare)

    def test_missing_observation_is_conservatively_active(self) -> None:
        quote = quote_route(self.runtime, "aTob", {})
        self.assertEqual(("a", "detour", "b"), quote.path)


if __name__ == "__main__":
    unittest.main()
