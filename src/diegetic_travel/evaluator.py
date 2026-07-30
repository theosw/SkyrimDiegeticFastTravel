from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, IntEnum
from typing import Mapping


class WarStage(IntEnum):
    EARLY = 1
    ACTIVE = 2
    RESOLVED = 3


class HazardPhase(Enum):
    DORMANT = "dormant"
    ACTIVE = "active"
    CLEARED = "cleared"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class HazardObservation:
    """The two live observations available to the Papyrus implementation."""

    cleared: bool | None = None
    marker_enabled: bool | None = None


@dataclass(frozen=True)
class Quote:
    available: bool
    fare: int | None
    hours: float | None
    path: tuple[str, ...]
    active_hazards: tuple[str, ...]
    blocked_candidates: int
    reason: str | None = None


def hazard_phase(
    hazard: Mapping[str, object],
    observation: HazardObservation,
    war_stage: WarStage,
) -> HazardPhase:
    hazard_class = str(hazard["class"])

    if hazard_class == "giant_camp":
        return HazardPhase.ACTIVE

    if observation.cleared is True:
        return HazardPhase.CLEARED

    if hazard_class == "cw_fort" and war_stage == WarStage.RESOLVED:
        return HazardPhase.CLEARED

    if hazard_class == "dragon_mound":
        if observation.marker_enabled is False:
            return HazardPhase.DORMANT
        if observation.marker_enabled is None or observation.cleared is None:
            return HazardPhase.UNKNOWN
        return HazardPhase.ACTIVE

    if observation.cleared is None:
        return HazardPhase.UNKNOWN
    return HazardPhase.ACTIVE


def _war_multiplier(rules: Mapping[str, object], war_stage: WarStage) -> int:
    multipliers = rules["war_multiplier"]
    assert isinstance(multipliers, Mapping)
    key = {
        WarStage.EARLY: "early",
        WarStage.ACTIVE: "active",
        WarStage.RESOLVED: "resolved",
    }[war_stage]
    return int(multipliers[key])


def quote_route(
    runtime: Mapping[str, object],
    route_id: str,
    observations: Mapping[str, HazardObservation],
    war_stage: WarStage = WarStage.EARLY,
    *,
    provider: str = "carriage",
) -> Quote:
    """Evaluate the same short candidate list Papyrus will evaluate in game.

    Missing observations are treated conservatively as active. Release builds
    reject missing form sensors before this point, but the conservative behavior
    keeps authoring diagnostics safe.
    """

    rules = runtime["rules"]
    hazards = runtime["hazards"]
    providers = runtime["providers"]
    assert isinstance(rules, Mapping)
    assert isinstance(hazards, Mapping)
    assert isinstance(providers, Mapping)

    provider_data = providers.get(provider)
    if not isinstance(provider_data, Mapping):
        return Quote(False, None, None, (), (), 0, f"unknown provider {provider!r}")
    routes = provider_data["routes"]
    assert isinstance(routes, Mapping)
    route = routes.get(route_id)
    if not isinstance(route, Mapping):
        return Quote(False, None, None, (), (), 0, f"unknown route {route_id!r}")

    base_cost = int(rules["base_cost"])
    hazard_cost = int(rules["hazard_cost"])
    refuse_multiplier = int(rules["refuse_multiplier"])
    provider_war_immune = bool(provider_data.get("war_immune", False))
    multiplier = 1 if provider_war_immune else _war_multiplier(rules, war_stage)

    best: tuple[int, float, tuple[str, ...], tuple[str, ...]] | None = None
    blocked = 0
    candidates = route["candidates"]
    assert isinstance(candidates, list)

    for candidate in candidates:
        assert isinstance(candidate, Mapping)
        fare = int(round(float(candidate["base_units"]) * base_cost * multiplier))
        active: list[str] = []
        is_blocked = False

        candidate_hazards = candidate.get("hazards", [])
        assert isinstance(candidate_hazards, list)
        for hazard_id in candidate_hazards:
            hazard = hazards[str(hazard_id)]
            assert isinstance(hazard, Mapping)
            phase = hazard_phase(
                hazard,
                observations.get(str(hazard_id), HazardObservation()),
                war_stage,
            )
            if phase in (HazardPhase.DORMANT, HazardPhase.CLEARED):
                continue

            # UNKNOWN is intentionally priced/blocked as ACTIVE.
            active.append(str(hazard_id))
            hazard_multiplier = int(hazard["mult"])
            if (
                hazard.get("role") == "chokepoint"
                and hazard_multiplier >= refuse_multiplier
            ):
                is_blocked = True
                break
            fare += hazard_cost * hazard_multiplier

        if is_blocked:
            blocked += 1
            continue

        path = tuple(str(node) for node in candidate["path"])
        hours = float(candidate["hours"])
        item = (fare, hours, path, tuple(active))
        if best is None or item[:3] < best[:3]:
            best = item

    if best is None:
        return Quote(
            False,
            None,
            None,
            (),
            (),
            blocked,
            "all candidate paths are blocked",
        )

    return Quote(True, best[0], best[1], best[2], best[3], blocked)

