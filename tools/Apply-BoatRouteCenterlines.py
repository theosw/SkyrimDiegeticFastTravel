#!/usr/bin/env python3
"""Apply extracted charcoal centerlines to the two boat Papyrus route graphs."""

from __future__ import annotations

import json
import re
from collections import deque
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXTRACTION = PROJECT_ROOT / ".tools/route-authoring/charcoal-extraction"

LANES = {
    "north_coast": {
        "source": PROJECT_ROOT / "modules/boat-north-coast/mod/Scripts/Source/DNT_NorthCoastBoatParchmentPicker.psc",
        "function": "AddNorthCoastNetwork",
        "markers": {
            "dragon_bridge": "0.247,0.219",
            "solitude": "0.330,0.150",
            "solitude_lighthouse": "0.384,0.098",
            "morthal": "0.402,0.298",
            "dawnstar": "0.570,0.177",
            "winterhold": "0.752,0.167",
            "windhelm": "0.812,0.372",
        },
    },
    "lake_honrich": {
        "source": PROJECT_ROOT / "modules/boat-honrich/mod/Scripts/Source/DNT_BoatParchmentPicker.psc",
        "function": "AddLaneNetwork",
        "markers": {
            "ivarstead": "0.686,0.713",
            "heartwood_mill": "0.814,0.806",
            "riften": "0.921,0.806",
        },
    },
}


def replace_function_body(text: str, function_name: str, body: str) -> str:
    pattern = re.compile(
        rf"(Bool Function {re.escape(function_name)}\(\)\n).*?(\nEndFunction)",
        re.DOTALL,
    )
    replacement = rf"\g<1>{body.rstrip()}\g<2>"
    updated, count = pattern.subn(replacement, text)
    if count != 1:
        raise RuntimeError(f"Expected one {function_name} function; found {count}.")
    return updated


def replace_marker_calls(text: str, marker_id: str, point: list[float]) -> tuple[str, int]:
    x, y = point
    coordinate = f"{x:.6f}, {y:.6f}"
    total = 0

    destination_patterns = (
        re.compile(
            rf'(AddStop\("{re.escape(marker_id)}",\s*"[^"]+",\s*)[0-9.]+,\s*[0-9.]+'
        ),
        re.compile(
            rf'(AddDestination\(ActiveRequest,\s*"{re.escape(marker_id)}",\s*"[^"]+",\s*Fare,\s*)[0-9.]+,\s*[0-9.]+'
        ),
    )
    for pattern in destination_patterns:
        text, count = pattern.subn(rf"\g<1>{coordinate}", text)
        total += count

    source_pattern = re.compile(
        rf'((?:If|ElseIf)\s+(?:SourceId|ActiveSourceId)\s*==\s*"{re.escape(marker_id)}".*?'
        rf'SetRouteOrigin\(ActiveRequest,\s*)[0-9.]+,\s*[0-9.]+',
        re.DOTALL,
    )
    text, count = source_pattern.subn(rf"\g<1>{coordinate}", text)
    total += count
    return text, total


def validate_connected_graph(
    text: str,
    marker_points: list[list[float]],
    lane: str,
) -> int:
    pattern = re.compile(
        r"AddRouteSegment\(ActiveRequest,\s*"
        r"([0-9.]+),\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)\)"
    )
    adjacency: dict[tuple[float, float], set[tuple[float, float]]] = {}
    for match in pattern.finditer(text):
        x1, y1, x2, y2 = (round(float(value), 6) for value in match.groups())
        start = (x1, y1)
        end = (x2, y2)
        adjacency.setdefault(start, set()).add(end)
        adjacency.setdefault(end, set()).add(start)
    segment_count = sum(len(neighbours) for neighbours in adjacency.values()) // 2
    if segment_count == 0 or segment_count > 192:
        raise RuntimeError(f"{lane} has invalid native segment count: {segment_count}.")

    markers = [(round(point[0], 6), round(point[1], 6)) for point in marker_points]
    missing = [point for point in markers if point not in adjacency]
    if missing:
        raise RuntimeError(f"{lane} markers are not exact graph nodes: {missing}.")

    visited = {markers[0]}
    queue = deque([markers[0]])
    while queue:
        current = queue.popleft()
        for neighbour in adjacency[current]:
            if neighbour not in visited:
                visited.add(neighbour)
                queue.append(neighbour)
    disconnected = [point for point in markers if point not in visited]
    if disconnected:
        raise RuntimeError(f"{lane} markers are disconnected from the route origin: {disconnected}.")
    return segment_count


def main() -> None:
    node_maps = json.loads((EXTRACTION / "charcoal-node-map.json").read_text(encoding="utf-8"))
    for lane, config in LANES.items():
        source = config["source"]
        text = source.read_text(encoding="utf-8").replace("\r\n", "\n")
        body = (EXTRACTION / f"{lane}-route-segments.psc.txt").read_text(encoding="utf-8")
        text = replace_function_body(text, config["function"], body)

        marker_replacements = 0
        marker_points = []
        for marker_id, canonical_key in config["markers"].items():
            marker_point = node_maps[lane][canonical_key]
            marker_points.append(marker_point)
            text, count = replace_marker_calls(text, marker_id, marker_point)
            marker_replacements += count
        if marker_replacements == 0:
            raise RuntimeError(f"No marker coordinates were updated in {source}.")

        segment_count = validate_connected_graph(text, marker_points, lane)
        source.write_text(text, encoding="utf-8", newline="\n")
        print(
            f"{lane}: applied {segment_count} connected centerline segments and "
            f"{marker_replacements} marker coordinate references"
        )


if __name__ == "__main__":
    main()
