#!/usr/bin/env python3
"""Extract one large connected component from a transparent RGBA image."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--side", choices=("left", "right"), required=True)
    parser.add_argument("--alpha-threshold", type=int, default=0)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    alpha = image.getchannel("A")
    width, height = image.size
    visited = bytearray(width * height)
    components: list[list[int]] = []

    def visible(index: int) -> bool:
        x = index % width
        y = index // width
        return alpha.getpixel((x, y)) > args.alpha_threshold

    for start in range(width * height):
        if visited[start] or not visible(start):
            continue
        visited[start] = 1
        queue = deque([start])
        component: list[int] = []
        while queue:
            index = queue.popleft()
            component.append(index)
            x = index % width
            y = index // width
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = ny * width + nx
                    if visited[neighbor] or not visible(neighbor):
                        continue
                    visited[neighbor] = 1
                    queue.append(neighbor)
        components.append(component)

    if not components:
        raise SystemExit("input contains no visible connected components")

    largest = max(len(component) for component in components)
    candidates = [component for component in components if len(component) >= largest * 0.25]
    if len(candidates) < 2:
        raise SystemExit(
            f"expected at least two large components; found {len(candidates)} "
            f"from {len(components)} total"
        )

    def centroid_x(component: list[int]) -> float:
        return sum(index % width for index in component) / len(component)

    selected = min(candidates, key=centroid_x) if args.side == "left" else max(candidates, key=centroid_x)
    selected_indices = set(selected)
    output = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source_pixels = image.load()
    output_pixels = output.load()
    for index in selected_indices:
        x = index % width
        y = index // width
        output_pixels[x, y] = source_pixels[x, y]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=True)
    print(
        f"extracted {args.side} component from {args.input} -> {args.output}; "
        f"components={len(components)}; selected_pixels={len(selected)}; "
        f"centroid_x={centroid_x(selected):.2f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
