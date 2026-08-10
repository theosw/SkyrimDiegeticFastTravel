#!/usr/bin/env python3
"""Fade residual dark matte pixels out of an RGBA marker image."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - (2.0 * value))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--low", type=int, default=48)
    parser.add_argument("--high", type=int, default=84)
    args = parser.parse_args()

    if not 0 <= args.low < args.high <= 255:
        raise SystemExit("expected 0 <= low < high <= 255")

    image = Image.open(args.input).convert("RGBA")
    pixels = image.load()
    faded = 0
    removed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            intensity = max(red, green, blue)
            if intensity <= args.low:
                pixels[x, y] = (red, green, blue, 0)
                removed += 1
            elif intensity < args.high:
                factor = smoothstep((intensity - args.low) / (args.high - args.low))
                new_alpha = round(alpha * factor)
                pixels[x, y] = (red, green, blue, new_alpha)
                faded += 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output, optimize=True)
    print(
        f"faded dark matte from {args.input} -> {args.output}; "
        f"low={args.low}; high={args.high}; faded={faded}; removed={removed}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
