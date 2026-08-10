#!/usr/bin/env python3
"""Make a dark edge-connected presentation background transparent."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--threshold", type=int, default=20)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    outside = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        return alpha == 0 or max(red, green, blue) <= args.threshold

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if visited[index] or not is_background(x, y):
            return
        visited[index] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        outside[y * width + x] = 1
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    output = image.copy()
    output_pixels = output.load()
    removed = 0
    for y in range(height):
        for x in range(width):
            if outside[y * width + x]:
                red, green, blue, _ = output_pixels[x, y]
                output_pixels[x, y] = (red, green, blue, 0)
                removed += 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=True)
    print(
        f"removed edge background from {args.input} -> {args.output}; "
        f"threshold={args.threshold}; transparent={removed}/{width * height}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
