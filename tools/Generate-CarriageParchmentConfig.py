#!/usr/bin/env python3
"""Build the beta carriage chart stop catalogue from audited map markers.

Seven visually verified capital positions shared with the clean wizard map act
as calibration points for a two-dimensional affine transform. CFTO's other
executable destinations are projected from their persistent Skyrim/HearthFires
map-marker references.
"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CALIBRATION_PATH = (
    ROOT / "modules" / "carriage-parchment" / "config" / "capital-slice.json"
)
ENDPOINTS_PATH = ROOT / "config" / "cfto_endpoints.json"
RUNTIME_PATH = ROOT / "build" / "runtime.json"
REPORT_PATH = ROOT / "build" / "carriage-parchment-inventory.report.txt"
OUTPUT_PATH = ROOT / "modules" / "carriage-parchment" / "config" / "network.json"


def solve_3x3(matrix: list[list[float]], vector: list[float]) -> list[float]:
    augmented = [row[:] + [value] for row, value in zip(matrix, vector)]
    for pivot in range(3):
        swap = max(range(pivot, 3), key=lambda row: abs(augmented[row][pivot]))
        if abs(augmented[swap][pivot]) < 1.0e-12:
            raise RuntimeError("Carriage parchment calibration matrix is singular")
        augmented[pivot], augmented[swap] = augmented[swap], augmented[pivot]
        divisor = augmented[pivot][pivot]
        augmented[pivot] = [value / divisor for value in augmented[pivot]]
        for row in range(3):
            if row == pivot:
                continue
            factor = augmented[row][pivot]
            augmented[row] = [
                value - factor * pivot_value
                for value, pivot_value in zip(augmented[row], augmented[pivot])
            ]
    return [augmented[row][3] for row in range(3)]


def fit_affine(samples: list[tuple[float, float, float]]) -> list[float]:
    # Least-squares normal equations for target = ax + by + c.
    rows = [[x, y, 1.0] for x, y, _ in samples]
    normal = [
        [sum(row[i] * row[j] for row in rows) for j in range(3)]
        for i in range(3)
    ]
    rhs = [
        sum(row[i] * sample[2] for row, sample in zip(rows, samples))
        for i in range(3)
    ]
    return solve_3x3(normal, rhs)


def project(coefficients: list[float], x: float, y: float) -> float:
    return coefficients[0] * x + coefficients[1] * y + coefficients[2]


def load_markers() -> dict[str, dict[str, object]]:
    pattern = re.compile(
        r"^MARKER=(?P<id>[^|]+)\|PLUGIN=(?P<plugin>[^|]+)"
        r"\|FORM=(?P<form>[0-9A-F]{8})\|EDID=(?P<edid>[^|]*)"
        r"\|X=(?P<x>-?[0-9.]+)\|Y=(?P<y>-?[0-9.]+)\|Z=(?P<z>-?[0-9.]+)$"
    )
    markers: dict[str, dict[str, object]] = {}
    if REPORT_PATH.exists():
        for line in REPORT_PATH.read_text(encoding="utf-8-sig").splitlines():
            match = pattern.match(line.strip())
            if not match:
                continue
            values = match.groupdict()
            markers[values["id"]] = {
                "plugin": values["plugin"],
                "form": values["form"],
                "editor_id": values["edid"],
                "world_position": [
                    float(values["x"]),
                    float(values["y"]),
                    float(values["z"]),
                ],
            }

    # The checked-in manifest is also a pinned inventory of the audited xEdit
    # marker records. It keeps coordinate-only regeneration deterministic when
    # the transient build report has been cleaned between sessions.
    if OUTPUT_PATH.exists():
        existing = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        for stop in existing.get("stops", []):
            marker = stop.get("marker")
            if marker and stop.get("id") not in markers:
                markers[stop["id"]] = marker
    return markers


def main() -> None:
    calibration = json.loads(CALIBRATION_PATH.read_text(encoding="utf-8"))
    endpoints = json.loads(ENDPOINTS_PATH.read_text(encoding="utf-8"))
    runtime = json.loads(RUNTIME_PATH.read_text(encoding="utf-8"))
    markers = load_markers()
    verified = {stop["id"]: stop for stop in calibration["stops"]}
    destination_ids = list(endpoints["destinations"])

    missing = sorted(set(destination_ids) - set(markers))
    if missing:
        raise RuntimeError(f"Missing audited carriage markers: {', '.join(missing)}")
    if len(destination_ids) != 27:
        raise RuntimeError(f"Expected 27 native CFTO destinations, found {len(destination_ids)}")

    u_samples: list[tuple[float, float, float]] = []
    v_samples: list[tuple[float, float, float]] = []
    for stop_id, stop in verified.items():
        x, y, _ = markers[stop_id]["world_position"]
        u, v = stop["map_position"]
        u_samples.append((x, y, u))
        v_samples.append((x, y, v))
    u_coefficients = fit_affine(u_samples)
    v_coefficients = fit_affine(v_samples)

    residuals: list[tuple[float, float]] = []
    for stop_id, stop in verified.items():
        x, y, _ = markers[stop_id]["world_position"]
        expected_u, expected_v = stop["map_position"]
        residuals.append(
            (
                project(u_coefficients, x, y) - expected_u,
                project(v_coefficients, x, y) - expected_v,
            )
        )

    stops: list[dict[str, object]] = []
    for stop_id in destination_ids:
        marker = markers[stop_id]
        x, y, _ = marker["world_position"]
        if stop_id in verified:
            map_position = verified[stop_id]["map_position"]
            placement = "verified_capital"
        else:
            map_position = [
                round(project(u_coefficients, x, y), 6),
                round(project(v_coefficients, x, y), 6),
            ]
            placement = "affine_from_map_marker"
        if not all(0.0 <= value <= 1.0 for value in map_position):
            raise RuntimeError(f"Projected marker is outside the parchment: {stop_id}")
        node = runtime["nodes"][stop_id]
        stops.append(
            {
                "id": stop_id,
                "name": node["name"],
                "type": node["type"],
                "map_position": map_position,
                "placement": placement,
                "marker": {
                    "plugin": marker["plugin"],
                    "form": marker["form"],
                    "editor_id": marker["editor_id"],
                    "world_position": marker["world_position"],
                },
            }
        )

    output = {
        "schema_version": 2,
        "provider": "carriage",
        "slice": "cfto_native_destinations",
        "authority": "DiegeticTravel.esp:DNT_TravelCoordinator",
        "execution": "Immediate Game.FastTravel to CFTO ground-level arrival XMarkerHeading after atomic parchment purchase",
        "map": calibration["map"],
        "icon_themes": {
            "default": "norden",
            "fallback": "vanilla",
        },
        "ui_elements": [
            {
                "id": "fare_label",
                "name": "Payment label",
                "sample": "Dawnstar to Windhelm (3.9 hours)    550 gold",
                "map_position": [0.615551, 0.922189],
            }
        ],
        "position_model": {
            "method": "two-dimensional affine least-squares fit",
            "calibration_stop_count": len(verified),
            "u_coefficients": [round(value, 12) for value in u_coefficients],
            "v_coefficients": [round(value, 12) for value in v_coefficients],
            "maximum_calibration_error": [
                round(max(abs(error[0]) for error in residuals), 6),
                round(max(abs(error[1]) for error in residuals), 6),
            ],
            "note": "Seven shared capitals retain visually verified clean-map positions; all other stops are beta placements derived from audited world-map references.",
        },
        "stops": stops,
        "deferred_destinations": {
            "helgen": "CFTO has no executable destination handoff.",
            "granite_hill": "CFTO has no executable destination handoff.",
        },
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    rmse_u = math.sqrt(sum(error[0] ** 2 for error in residuals) / len(residuals))
    rmse_v = math.sqrt(sum(error[1] ** 2 for error in residuals) / len(residuals))
    print(f"Generated {OUTPUT_PATH}")
    print(f"Stops: {len(stops)}; calibration RMSE: ({rmse_u:.6f}, {rmse_v:.6f})")


if __name__ == "__main__":
    main()
