from __future__ import annotations

from collections import defaultdict
from copy import deepcopy
import heapq
import math
from typing import Iterable, Mapping

from .forms import canonical_form, jcontainers_form

UNITS_PER_FOOT = 21.3
DEFAULT_ATTACH_DISTANCE = 14_000
DEFAULT_K_PATHS = 3


class CompileError(ValueError):
    pass


def _segment_distance(
    point: tuple[float, float],
    start: tuple[float, float],
    end: tuple[float, float],
) -> float:
    ax, ay = start
    bx, by = end
    px, py = point
    dx, dy = bx - ax, by - ay
    length_sq = dx * dx + dy * dy
    if length_sq == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length_sq))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def _position(node: Mapping[str, object]) -> tuple[float, float] | None:
    raw = node.get("pos")
    if not isinstance(raw, list) or len(raw) < 2:
        return None
    return float(raw[0]), float(raw[1])


def _attach_proximity_hazards(
    nodes: Mapping[str, Mapping[str, object]],
    hazards: Mapping[str, Mapping[str, object]],
    edges: list[dict[str, object]],
    *,
    attach_distance: float,
) -> list[dict[str, object]]:
    candidates: dict[str, list[tuple[float, int]]] = defaultdict(list)
    for edge_index, edge in enumerate(edges):
        start = _position(nodes[str(edge["a"])])
        end = _position(nodes[str(edge["b"])])
        if start is None or end is None:
            continue
        existing = set(str(value) for value in edge.get("hazards", []))
        for hazard_id, hazard in hazards.items():
            if hazard.get("role") != "proximity" or hazard_id in existing:
                continue
            point = _position(hazard)
            if point is None:
                continue
            distance = _segment_distance(point, start, end)
            if distance < attach_distance:
                candidates[hazard_id].append((distance, edge_index))

    report: list[dict[str, object]] = []
    for hazard_id, matches in sorted(candidates.items()):
        for distance, edge_index in sorted(matches)[:2]:
            edge_hazards = edges[edge_index].setdefault("hazards", [])
            assert isinstance(edge_hazards, list)
            edge_hazards.append(hazard_id)
            report.append(
                {
                    "edge": f'{edges[edge_index]["a"]}–{edges[edge_index]["b"]}',
                    "hazard": hazard_id,
                    "distance_feet": int(distance / UNITS_PER_FOOT),
                }
            )
    return report


def _dijkstra(
    source: str,
    adjacency: Mapping[str, list[tuple[str, float, int]]],
    *,
    banned_edges: frozenset[int] = frozenset(),
    banned_nodes: frozenset[str] = frozenset(),
) -> tuple[dict[str, float], dict[str, tuple[str, int]]]:
    distances = {source: 0.0}
    previous: dict[str, tuple[str, int]] = {}
    queue: list[tuple[float, str]] = [(0.0, source)]
    while queue:
        current_distance, node = heapq.heappop(queue)
        if current_distance > distances.get(node, math.inf):
            continue
        for neighbor, weight, edge_index in adjacency.get(node, []):
            if edge_index in banned_edges or neighbor in banned_nodes:
                continue
            next_distance = current_distance + weight
            if next_distance < distances.get(neighbor, math.inf) - 1e-9:
                distances[neighbor] = next_distance
                previous[neighbor] = (node, edge_index)
                heapq.heappush(queue, (next_distance, neighbor))
    return distances, previous


def _extract_path(
    source: str,
    destination: str,
    distances: Mapping[str, float],
    previous: Mapping[str, tuple[str, int]],
) -> dict[str, object] | None:
    if destination not in distances:
        return None
    path = [destination]
    edge_ids: list[int] = []
    current = destination
    while current != source:
        prior, edge_index = previous[current]
        edge_ids.append(edge_index)
        path.append(prior)
        current = prior
    path.reverse()
    edge_ids.reverse()
    return {
        "base_units": float(distances[destination]),
        "path": path,
        "edge_ids": edge_ids,
    }


def _k_shortest(
    source: str,
    destination: str,
    adjacency: Mapping[str, list[tuple[str, float, int]]],
    edges: list[dict[str, object]],
    *,
    count: int,
) -> list[dict[str, object]]:
    distances, previous = _dijkstra(source, adjacency)
    first = _extract_path(source, destination, distances, previous)
    if first is None:
        return []

    accepted = [first]
    candidates: list[tuple[float, int, dict[str, object]]] = []
    tie_breaker = 0

    while len(accepted) < count:
        base = accepted[-1]
        base_path = base["path"]
        base_edges = base["edge_ids"]
        assert isinstance(base_path, list)
        assert isinstance(base_edges, list)

        for index in range(len(base_path) - 1):
            spur = str(base_path[index])
            root_path = [str(value) for value in base_path[: index + 1]]
            root_edges = [int(value) for value in base_edges[:index]]
            banned_edges: set[int] = set()
            for accepted_path in accepted:
                accepted_nodes = accepted_path["path"]
                accepted_edges = accepted_path["edge_ids"]
                assert isinstance(accepted_nodes, list)
                assert isinstance(accepted_edges, list)
                if accepted_nodes[: index + 1] == root_path and len(accepted_edges) > index:
                    banned_edges.add(int(accepted_edges[index]))

            distances, previous = _dijkstra(
                spur,
                adjacency,
                banned_edges=frozenset(banned_edges),
                banned_nodes=frozenset(root_path[:-1]),
            )
            tail = _extract_path(spur, destination, distances, previous)
            if tail is None:
                continue

            tail_path = tail["path"]
            tail_edges = tail["edge_ids"]
            assert isinstance(tail_path, list)
            assert isinstance(tail_edges, list)
            candidate = {
                "base_units": sum(float(edges[edge_id]["weight"]) for edge_id in root_edges)
                + float(tail["base_units"]),
                "path": root_path[:-1] + tail_path,
                "edge_ids": root_edges + tail_edges,
            }
            if any(item["path"] == candidate["path"] for item in accepted):
                continue
            if any(item["path"] == candidate["path"] for _, _, item in candidates):
                continue
            tie_breaker += 1
            heapq.heappush(
                candidates,
                (float(candidate["base_units"]), tie_breaker, candidate),
            )

        if not candidates:
            break
        accepted.append(heapq.heappop(candidates)[2])
    return accepted


def _candidate_hazards(
    candidate: Mapping[str, object],
    edges: list[dict[str, object]],
    nodes: Mapping[str, Mapping[str, object]],
) -> list[str]:
    result: set[str] = set()
    edge_ids = candidate["edge_ids"]
    path = candidate["path"]
    assert isinstance(edge_ids, list)
    assert isinstance(path, list)
    for edge_id in edge_ids:
        result.update(str(value) for value in edges[int(edge_id)].get("hazards", []))
    for node_id in path[1:-1]:
        hazard = nodes[str(node_id)].get("hazard")
        if hazard:
            result.add(str(hazard))
    return sorted(result)


def _candidate_hours(
    candidate: Mapping[str, object],
    edges: list[dict[str, object]],
    *,
    speed: float,
    fallback_distance: float,
) -> float:
    total = 0.0
    edge_ids = candidate["edge_ids"]
    assert isinstance(edge_ids, list)
    for edge_id in edge_ids:
        edge = edges[int(edge_id)]
        total += float(edge.get("_distance", fallback_distance * float(edge["weight"])))
    return round(total / speed, 1)


def _sensor_issues(
    hazards: Mapping[str, Mapping[str, object]],
    used_hazards: Iterable[str],
) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    for hazard_id in sorted(set(used_hazards)):
        hazard = hazards[hazard_id]
        hazard_class = str(hazard["class"])
        clears_on_death = bool(hazard.get("clears_on_death", False))
        if (
            hazard_class != "giant_camp"
            and not hazard.get("location")
            and not clears_on_death
        ):
            issues.append(
                {
                    "severity": "error",
                    "hazard": hazard_id,
                    "field": "location",
                    "message": "hazard cannot detect cleared state",
                }
            )
        if hazard_class == "dragon_mound" and not hazard.get("activation_ref"):
            issues.append(
                {
                    "severity": "error",
                    "hazard": hazard_id,
                    "field": "activation_ref",
                    "message": "dragon mound cannot distinguish dormant from active",
                }
            )
    return issues


def compile_provider(
    graph: Mapping[str, object],
    provider: str,
    *,
    path_count: int = DEFAULT_K_PATHS,
    attach_distance: float = DEFAULT_ATTACH_DISTANCE,
) -> tuple[dict[str, object], dict[str, object]]:
    nodes = deepcopy(graph["nodes"])
    hazards = deepcopy(graph["hazards"])
    all_edges = deepcopy(graph["edges"])
    if not isinstance(nodes, dict) or not isinstance(hazards, dict) or not isinstance(all_edges, list):
        raise CompileError("graph must contain object nodes/hazards and an array of edges")

    edges = [edge for edge in all_edges if edge.get("provider") == provider]
    if not edges:
        raise CompileError(f"graph has no {provider!r} edges")

    auto_attached = _attach_proximity_hazards(
        nodes,
        hazards,
        edges,
        attach_distance=attach_distance,
    )

    edge_distances: list[float] = []
    adjacency: dict[str, list[tuple[str, float, int]]] = defaultdict(list)
    for edge_index, edge in enumerate(edges):
        start_id = str(edge["a"])
        end_id = str(edge["b"])
        if start_id not in nodes or end_id not in nodes:
            raise CompileError(f"edge references missing node: {start_id}–{end_id}")
        weight = float(edge["weight"])
        adjacency[start_id].append((end_id, weight, edge_index))
        adjacency[end_id].append((start_id, weight, edge_index))
        start = _position(nodes[start_id])
        end = _position(nodes[end_id])
        if start is not None and end is not None:
            distance = math.hypot(start[0] - end[0], start[1] - end[1])
            edge["_distance"] = distance
            if weight == 1:
                edge_distances.append(distance)

    edge_distances.sort()
    fallback_distance = edge_distances[len(edge_distances) // 2] if edge_distances else 1.0
    speed = float(graph["rules"]["time"]["speed_units_per_hour"])
    serviced = [
        node_id
        for node_id, node in nodes.items()
        if provider in node.get("providers", [])
    ]

    routes: dict[str, object] = {}
    unreachable: list[str] = []
    used_hazards: set[str] = set()
    for source in serviced:
        for destination in serviced:
            if source == destination:
                continue
            candidates = _k_shortest(
                source,
                destination,
                adjacency,
                edges,
                count=path_count,
            )
            if not candidates:
                unreachable.append(f"{source}To{destination}")
                continue
            compiled_candidates = []
            for candidate in candidates:
                candidate_hazards = _candidate_hazards(candidate, edges, nodes)
                used_hazards.update(candidate_hazards)
                endpoint_conditions = sorted(
                    {
                        str(nodes[node_id]["condition"])
                        for node_id in (source, destination)
                        if nodes[node_id].get("condition")
                    }
                )
                compiled_candidates.append(
                    {
                        "base_units": round(float(candidate["base_units"]), 1),
                        "hours": _candidate_hours(
                            candidate,
                            edges,
                            speed=speed,
                            fallback_distance=fallback_distance,
                        ),
                        "path": candidate["path"],
                        "hazards": candidate_hazards,
                        "conditions": endpoint_conditions,
                    }
                )
            routes[f"{source}To{destination}"] = {"candidates": compiled_candidates}

    provider_runtime = {
        "war_immune": bool(
            provider == "ferry"
            and graph["rules"].get("ferry_immune_to_war_multiplier", False)
        ),
        "serviced_nodes": serviced,
        "routes": routes,
    }
    report = {
        "provider": provider,
        "serviced_nodes": len(serviced),
        "route_pairs": len(routes),
        "average_candidates": round(
            sum(len(route["candidates"]) for route in routes.values()) / max(1, len(routes)),
            2,
        ),
        "unreachable": unreachable,
        "ignored_other_provider_edges": len(all_edges) - len(edges),
        "auto_attached": auto_attached,
        "used_hazards": sorted(used_hazards),
        "sensor_issues": _sensor_issues(hazards, used_hazards),
    }
    return provider_runtime, report


def compile_runtime(
    graph: Mapping[str, object],
    *,
    providers: Iterable[str] = ("carriage",),
    sensor_overrides: Mapping[str, object] | None = None,
) -> tuple[dict[str, object], dict[str, object]]:
    graph = deepcopy(graph)
    if sensor_overrides:
        override_hazards = sensor_overrides.get("hazards", {})
        if not isinstance(override_hazards, Mapping):
            raise CompileError("sensor override hazards must be an object")
        for hazard_id, override in override_hazards.items():
            if hazard_id not in graph["hazards"]:
                raise CompileError(f"sensor override references unknown hazard {hazard_id!r}")
            if not isinstance(override, Mapping):
                raise CompileError(f"sensor override for {hazard_id!r} must be an object")
            for field in ("location", "activation_ref", "clears_on_death"):
                if field in override:
                    graph["hazards"][hazard_id][field] = override[field]

    rules = graph["rules"]
    runtime_rules = {
        "base_cost": int(rules["base_cost"]),
        "hazard_cost": int(rules["hazard_cost"]),
        "refuse_multiplier": 2,
        "war_multiplier": {
            key: int(rules["war_multiplier"][key])
            for key in ("early", "active", "resolved")
        },
        "war_quests": {
            key: jcontainers_form(value)
            for key, value in rules["war_multiplier"]["quests"].items()
        },
    }

    runtime_nodes: dict[str, object] = {}
    for node_id, node in graph["nodes"].items():
        runtime_nodes[node_id] = {
            "name": node["name"],
            "type": node["type"],
            "marker": jcontainers_form(node.get("marker")),
            "condition": node.get("condition"),
        }

    runtime_hazards: dict[str, object] = {}
    for hazard_id, hazard in graph["hazards"].items():
        runtime_hazards[hazard_id] = {
            "name": hazard["name"],
            "class": hazard["class"],
            "mult": int(hazard["mult"]),
            "role": hazard["role"],
            "location": jcontainers_form(hazard.get("location")),
            "activation_ref": jcontainers_form(hazard.get("activation_ref")),
            "clears_on_death": bool(hazard.get("clears_on_death", False)),
        }

    provider_output: dict[str, object] = {}
    provider_reports: dict[str, object] = {}
    for provider in providers:
        provider_output[provider], provider_reports[provider] = compile_provider(
            graph,
            provider,
        )

    runtime = {
        "meta": {
            "name": graph.get("meta", {}).get("name", "Diegetic Travel"),
            "source_version": graph.get("meta", {}).get("version"),
            "generated_against": graph.get("meta", {}).get("generated_against"),
        },
        "rules": runtime_rules,
        "nodes": runtime_nodes,
        "hazards": runtime_hazards,
        "providers": provider_output,
    }
    report = {"providers": provider_reports}
    return runtime, report


def validate_endpoint_config(
    runtime: Mapping[str, object],
    endpoints: Mapping[str, object],
    *,
    provider: str = "carriage",
) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    provider_data = runtime["providers"][provider]
    serviced_nodes = set(provider_data["serviced_nodes"])
    origins = endpoints["origins"]
    destinations = endpoints["destinations"]
    dialogue_destinations = endpoints.get("dialogue", {}).get("destinations", {})
    custom = endpoints.get("custom_destinations", {})

    integration_forms = {
        "quest": endpoints.get("quest"),
        "destination_global": endpoints.get("destination_global"),
        "free_faction": endpoints.get("free_faction"),
        "branch": endpoints.get("dialogue", {}).get("branch"),
        "root_topic": endpoints.get("dialogue", {}).get("root_topic"),
        "root_info": endpoints.get("dialogue", {}).get("root_info"),
        "free_root_info": endpoints.get("dialogue", {}).get("free_root_info"),
    }
    for field, value in integration_forms.items():
        try:
            if not isinstance(value, str) or not value:
                raise ValueError("form reference is missing")
            canonical_form(value)
        except (TypeError, ValueError) as error:
            issues.append(
                {
                    "severity": "error",
                    "endpoint": "$integration",
                    "message": f"invalid {field} form: {error}",
                }
            )

    for origin, data in origins.items():
        if origin not in serviced_nodes:
            issues.append(
                {
                    "severity": "error",
                    "endpoint": origin,
                    "message": "configured origin is not serviced by provider",
                }
            )
        try:
            canonical_form(data["driver"])
        except (KeyError, ValueError) as error:
            issues.append(
                {
                    "severity": "error",
                    "endpoint": origin,
                    "message": f"invalid driver form: {error}",
                }
            )

    covered = set(destinations) | set(custom)
    for node_id in sorted(serviced_nodes - covered):
        issues.append(
            {
                "severity": "error",
                "endpoint": node_id,
                "message": "serviced node has no CFTO or custom destination mapping",
            }
        )
    for node_id in sorted(set(destinations) - serviced_nodes):
        issues.append(
            {
                "severity": "error",
                "endpoint": node_id,
                "message": "CFTO destination is not serviced by provider",
            }
        )
    for node_id in sorted(set(destinations) - set(dialogue_destinations)):
        issues.append(
            {
                "severity": "error",
                "endpoint": node_id,
                "message": "CFTO destination has no dialogue record mapping",
            }
        )
    for node_id, data in dialogue_destinations.items():
        if node_id not in destinations:
            issues.append(
                {
                    "severity": "error",
                    "endpoint": node_id,
                    "message": "dialogue mapping has no CFTO destination code",
                }
            )
            continue
        for field in ("topic", "success_info", "failure_info"):
            try:
                canonical_form(data[field])
            except (KeyError, ValueError) as error:
                issues.append(
                    {
                        "severity": "error",
                        "endpoint": node_id,
                        "message": f"invalid {field} form: {error}",
                    }
                )
    return issues


def build_dialogue_manifest(
    runtime: Mapping[str, object],
    endpoints: Mapping[str, object],
    *,
    provider: str = "carriage",
) -> dict[str, object]:
    nodes = runtime["nodes"]
    destinations = endpoints["destinations"]
    origins = endpoints["origins"]
    dialogue = endpoints["dialogue"]
    dialogue_destinations = dialogue["destinations"]
    supported = sorted(destinations, key=lambda node_id: str(nodes[node_id]["name"]))

    globals_by_destination = {}
    for destination in supported:
        token = "".join(part.capitalize() for part in destination.split("_"))
        globals_by_destination[destination] = {
            "available": f"DNT_Available_{token}",
            "cost": f"DNT_Cost_{token}",
            "hours": f"DNT_Hours_{token}",
        }

    origin_entries = {}
    for origin, origin_data in origins.items():
        entries = []
        for destination in supported:
            if destination == origin:
                continue
            route_id = f"{origin}To{destination}"
            entries.append(
                {
                    "destination": destination,
                    "name": nodes[destination]["name"],
                    "cfto_destination": int(destinations[destination]),
                    "route": route_id,
                    "globals": globals_by_destination[destination],
                }
            )
        origin_entries[origin] = {
            "driver": jcontainers_form(origin_data["driver"]),
            "entries": entries,
        }

    return {
        "plugin": "DiegeticTravel.esp",
        "provider": provider,
        "cfto": {
            "quest": jcontainers_form(endpoints["quest"]),
            "destination_global": jcontainers_form(endpoints["destination_global"]),
            "free_faction": jcontainers_form(endpoints["free_faction"]),
        },
        "dialogue": {
            "branch": jcontainers_form(dialogue["branch"]),
            "root_topic": jcontainers_form(dialogue["root_topic"]),
            "root_info": jcontainers_form(dialogue["root_info"]),
            "free_root_info": jcontainers_form(dialogue["free_root_info"]),
            "destinations": {
                node_id: {
                    "name": nodes[node_id]["name"],
                    **{
                        field: jcontainers_form(data[field])
                        for field in ("topic", "success_info", "failure_info")
                    },
                }
                for node_id, data in dialogue_destinations.items()
            },
        },
        "globals": globals_by_destination,
        "origins": origin_entries,
        "deferred_custom_destinations": endpoints.get("custom_destinations", {}),
    }
