#!/usr/bin/env python3
"""Extract editable route centerlines from the user-authored charcoal overlay."""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CANVAS_WIDTH = 4096
CANVAS_HEIGHT = 3016
WORK_WIDTH = 2048
WORK_HEIGHT = 1508


def shifted(image: np.ndarray, dy: int, dx: int) -> np.ndarray:
    result = np.zeros_like(image)
    source_y0 = max(0, -dy)
    source_y1 = image.shape[0] - max(0, dy)
    source_x0 = max(0, -dx)
    source_x1 = image.shape[1] - max(0, dx)
    target_y0 = max(0, dy)
    target_y1 = image.shape[0] - max(0, -dy)
    target_x0 = max(0, dx)
    target_x1 = image.shape[1] - max(0, -dx)
    result[target_y0:target_y1, target_x0:target_x1] = image[
        source_y0:source_y1, source_x0:source_x1
    ]
    return result


def zhang_suen(mask: np.ndarray) -> np.ndarray:
    image = mask.astype(bool, copy=True)
    changed = True
    while changed:
        changed = False
        for first_step in (True, False):
            p2 = shifted(image, 1, 0)
            p3 = shifted(image, 1, -1)
            p4 = shifted(image, 0, -1)
            p5 = shifted(image, -1, -1)
            p6 = shifted(image, -1, 0)
            p7 = shifted(image, -1, 1)
            p8 = shifted(image, 0, 1)
            p9 = shifted(image, 1, 1)
            neighbours = (p2.astype(np.uint8) + p3 + p4 + p5 + p6 + p7 + p8 + p9)
            transitions = (
                (~p2 & p3).astype(np.uint8)
                + (~p3 & p4)
                + (~p4 & p5)
                + (~p5 & p6)
                + (~p6 & p7)
                + (~p7 & p8)
                + (~p8 & p9)
                + (~p9 & p2)
            )
            if first_step:
                connectivity = ~(p2 & p4 & p6) & ~(p4 & p6 & p8)
            else:
                connectivity = ~(p2 & p4 & p8) & ~(p2 & p6 & p8)
            remove = image & (neighbours >= 2) & (neighbours <= 6) & (transitions == 1) & connectivity
            remove[[0, -1], :] = False
            remove[:, [0, -1]] = False
            if np.any(remove):
                image[remove] = False
                changed = True
    return image


def parse_edges(source: Path) -> list[tuple[tuple[float, float], tuple[float, float]]]:
    text = source.read_text(encoding="utf-8")
    pattern = re.compile(
        r"AddRouteSegment\(ActiveRequest,\s*"
        r"([0-9.]+),\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)\)"
    )
    edges = []
    for match in pattern.finditer(text):
        x1, y1, x2, y2 = (float(value) for value in match.groups())
        edges.append(((x1, y1), (x2, y2)))
    return edges


def nearest_skeleton_points(
    skeleton: np.ndarray,
    normalized_points: set[tuple[float, float]],
) -> dict[tuple[float, float], tuple[int, int]]:
    pixels_yx = np.argwhere(skeleton)
    if len(pixels_yx) == 0:
        raise RuntimeError("Charcoal mask did not produce any skeleton pixels.")
    tree = cKDTree(pixels_yx.astype(np.float64))
    snapped: dict[tuple[float, float], tuple[int, int]] = {}
    for point in normalized_points:
        query = np.array([point[1] * (WORK_HEIGHT - 1), point[0] * (WORK_WIDTH - 1)])
        _, index = tree.query(query)
        y, x = pixels_yx[int(index)]
        snapped[point] = (int(y), int(x))
    return snapped


NEIGHBOURS = (
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1), (0, 1),
    (1, -1), (1, 0), (1, 1),
)


def skeleton_path(
    skeleton: np.ndarray,
    start: tuple[int, int],
    goal: tuple[int, int],
) -> list[tuple[float, float]]:
    if start == goal:
        return [(float(start[1]), float(start[0]))]
    queue: deque[tuple[int, int]] = deque([start])
    parents: dict[tuple[int, int], tuple[int, int] | None] = {start: None}
    height, width = skeleton.shape
    found = False
    while queue and not found:
        current = queue.popleft()
        for dy, dx in NEIGHBOURS:
            candidate = (current[0] + dy, current[1] + dx)
            if (
                candidate in parents
                or candidate[0] < 0
                or candidate[0] >= height
                or candidate[1] < 0
                or candidate[1] >= width
                or not skeleton[candidate]
            ):
                continue
            parents[candidate] = current
            if candidate == goal:
                found = True
                break
            queue.append(candidate)
    if goal not in parents:
        raise RuntimeError(f"No charcoal skeleton path between {start} and {goal}.")
    reversed_path = []
    current: tuple[int, int] | None = goal
    while current is not None:
        reversed_path.append((float(current[1]), float(current[0])))
        current = parents[current]
    return list(reversed(reversed_path))


def perpendicular_distance(point: tuple[float, float], start: tuple[float, float], end: tuple[float, float]) -> float:
    if start == end:
        return math.dist(point, start)
    numerator = abs(
        (end[1] - start[1]) * point[0]
        - (end[0] - start[0]) * point[1]
        + end[0] * start[1]
        - end[1] * start[0]
    )
    return numerator / math.dist(start, end)


def simplify(points: list[tuple[float, float]], epsilon: float = 3.0) -> list[tuple[float, float]]:
    if len(points) <= 2:
        return points
    start, end = points[0], points[-1]
    distances = [perpendicular_distance(point, start, end) for point in points[1:-1]]
    if not distances:
        return [start, end]
    maximum = max(distances)
    index = distances.index(maximum) + 1
    if maximum <= epsilon:
        return [start, end]
    left = simplify(points[: index + 1], epsilon)
    right = simplify(points[index:], epsilon)
    return left[:-1] + right


def full_canvas_points(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return [
        (
            x * CANVAS_WIDTH / WORK_WIDTH,
            y * CANVAS_HEIGHT / WORK_HEIGHT,
        )
        for x, y in points
    ]


def svg_path(points: list[tuple[float, float]]) -> str:
    if not points:
        return ""
    commands = [f"M {points[0][0]:.2f},{points[0][1]:.2f}"]
    commands.extend(f"L {x:.2f},{y:.2f}" for x, y in points[1:])
    return " ".join(commands)


def route_segment_key(
    start: list[float],
    end: list[float],
) -> tuple[tuple[float, float], tuple[float, float]]:
    """Return an undirected, stable key for one normalized route segment."""
    first = (round(start[0], 6), round(start[1], 6))
    second = (round(end[0], 6), round(end[1], 6))
    return tuple(sorted((first, second)))


def papyrus_route_block(lane_edges: list[dict[str, object]]) -> tuple[str, int, int]:
    """Emit a de-duplicated Papyrus AddRouteSegment block."""
    segments: list[tuple[list[float], list[float]]] = []
    seen: set[tuple[tuple[float, float], tuple[float, float]]] = set()
    duplicate_count = 0
    for edge in lane_edges:
        points = edge["snapped_points"]
        assert isinstance(points, list)
        for start, end in zip(points, points[1:]):
            key = route_segment_key(start, end)
            if key in seen:
                duplicate_count += 1
                continue
            seen.add(key)
            segments.append((start, end))

    lines = []
    for index, (start, end) in enumerate(segments):
        prefix = "Bool AddedAll = " if index == 0 else "AddedAll = "
        suffix = "" if index == 0 else " && AddedAll"
        lines.append(
            f"    {prefix}DNT_ParchmentNative.AddRouteSegment(ActiveRequest, "
            f"{start[0]:.6f}, {start[1]:.6f}, {end[0]:.6f}, {end[1]:.6f}){suffix}"
        )
    lines.append("    Return AddedAll")
    return "\n".join(lines) + "\n", len(segments), duplicate_count


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=PROJECT_ROOT / ".tools/route-authoring/boat-route-chalk-overlay.png",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=PROJECT_ROOT / ".tools/route-authoring/charcoal-extraction",
    )
    parser.add_argument(
        "--graph",
        type=Path,
        default=PROJECT_ROOT / "assets/route-overlays/boat-route-control-graph.json",
        help="Canonical logical graph used to split the charcoal skeleton into selectable routes.",
    )
    args = parser.parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    graph_data = json.loads(args.graph.resolve().read_text(encoding="utf-8"))

    overlay = Image.open(source).convert("RGBA")
    if overlay.size != (CANVAS_WIDTH, CANVAS_HEIGHT):
        raise RuntimeError(f"Expected {CANVAS_WIDTH}x{CANVAS_HEIGHT}; found {overlay.size}.")
    alpha = overlay.getchannel("A").resize((WORK_WIDTH, WORK_HEIGHT), Image.Resampling.LANCZOS)
    mask = np.asarray(alpha, dtype=np.uint8) >= 8
    mask = ndimage.binary_closing(
        mask,
        structure=np.ones((3, 3), dtype=bool),
        iterations=1,
    )
    skeleton = zhang_suen(mask)

    skeleton_image = Image.new("RGBA", (WORK_WIDTH, WORK_HEIGHT), (0, 0, 0, 0))
    skeleton_alpha = Image.fromarray((skeleton.astype(np.uint8) * 255), mode="L")
    skeleton_image.putalpha(skeleton_alpha)
    skeleton_image.save(output / "charcoal-skeleton-half-resolution.png")

    lanes = ("north_coast", "lake_honrich")
    extracted: dict[str, list[dict[str, object]]] = {}
    node_maps: dict[str, dict[str, list[float]]] = {}
    svg_groups = []
    preview = Image.open(
        PROJECT_ROOT / ".tools/route-authoring/battlemap01-crop-local.png"
    ).convert("RGBA")
    preview.alpha_composite(overlay)
    draw = ImageDraw.Draw(preview, "RGBA")

    for lane in lanes:
        edges = [
            (tuple(edge[0]), tuple(edge[1]))
            for edge in graph_data[lane]
        ]
        points = {point for edge in edges for point in edge}
        snapped = nearest_skeleton_points(skeleton, points)
        node_maps[lane] = {
            f"{point[0]:.3f},{point[1]:.3f}": [
                round(pixel[1] / WORK_WIDTH, 6),
                round(pixel[0] / WORK_HEIGHT, 6),
            ]
            for point, pixel in sorted(snapped.items())
        }
        lane_edges = []
        svg_edges = []
        for index, edge in enumerate(edges):
            raw_path = skeleton_path(skeleton, snapped[edge[0]], snapped[edge[1]])
            simple_path = simplify(raw_path)
            full_path = full_canvas_points(simple_path)
            draw.line(full_path, fill=(0, 255, 255, 235), width=7, joint="curve")
            normalized_path = [
                [round(x / CANVAS_WIDTH, 6), round(y / CANVAS_HEIGHT, 6)]
                for x, y in full_path
            ]
            lane_edges.append({
                "source_edge": [list(edge[0]), list(edge[1])],
                "snapped_points": normalized_path,
            })
            svg_edges.append(
                f'    <path id="{lane}-edge-{index:02d}" d="{svg_path(full_path)}" />'
            )
        extracted[lane] = lane_edges
        svg_groups.append(
            f'  <g id="{lane}" inkscape:groupmode="layer" inkscape:label="{lane} extracted centerlines">\n'
            + "\n".join(svg_edges)
            + "\n  </g>"
        )

    preview.save(output / "charcoal-centerline-preview.png")
    (output / "charcoal-centerlines.json").write_text(
        json.dumps(extracted, indent=2) + "\n",
        encoding="utf-8",
    )
    (output / "charcoal-node-map.json").write_text(
        json.dumps(node_maps, indent=2) + "\n",
        encoding="utf-8",
    )
    papyrus_counts: dict[str, tuple[int, int]] = {}
    for lane, lane_edges in extracted.items():
        block, segment_count, duplicate_count = papyrus_route_block(lane_edges)
        (output / f"{lane}-route-segments.psc.txt").write_text(block, encoding="utf-8")
        papyrus_counts[lane] = (segment_count, duplicate_count)
    svg = f'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
     width="{CANVAS_WIDTH}" height="{CANVAS_HEIGHT}"
     viewBox="0 0 {CANVAS_WIDTH} {CANVAS_HEIGHT}">
  <image id="map-reference" x="0" y="0" width="{CANVAS_WIDTH}" height="{CANVAS_HEIGHT}"
         xlink:href="../battlemap01-crop-local.png" opacity="1" />
  <image id="charcoal-reference" x="0" y="0" width="{CANVAS_WIDTH}" height="{CANVAS_HEIGHT}"
         xlink:href="../boat-route-chalk-overlay.png" opacity="1" />
  <g style="fill:none;stroke:#00ffff;stroke-width:7;stroke-linecap:round;stroke-linejoin:round">
{chr(10).join(svg_groups)}
  </g>
</svg>
'''
    (output / "charcoal-centerlines.svg").write_text(svg, encoding="utf-8")

    print(f"Skeleton pixels: {int(skeleton.sum())}")
    for lane, edges in extracted.items():
        segment_count, duplicate_count = papyrus_counts[lane]
        print(
            f"{lane}: {len(edges)} snapped graph edges, "
            f"{segment_count} native segments, {duplicate_count} duplicates removed"
        )
    print(f"Preview: {output / 'charcoal-centerline-preview.png'}")
    print(f"SVG: {output / 'charcoal-centerlines.svg'}")
    print(f"JSON: {output / 'charcoal-centerlines.json'}")
    print(f"Node map: {output / 'charcoal-node-map.json'}")


if __name__ == "__main__":
    main()
