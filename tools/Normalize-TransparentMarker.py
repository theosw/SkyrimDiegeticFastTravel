#!/usr/bin/env python3
"""Normalize a transparent marker onto a fixed square canvas."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--canvas", type=int, default=512)
    parser.add_argument("--max-width", type=int, default=448)
    parser.add_argument("--max-height", type=int, default=448)
    parser.add_argument(
        "--bounds-from",
        type=Path,
        help="use the alpha bounds of this reference image so related layers share one transform",
    )
    parser.add_argument(
        "--normalize-alpha-max",
        action="store_true",
        help="scale the strongest nonzero alpha to 255 while preserving edge antialiasing",
    )
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    bounds_image = image
    if args.bounds_from is not None:
        bounds_image = Image.open(args.bounds_from).convert("RGBA")
        if bounds_image.size != image.size:
            raise SystemExit("bounds reference must use the same canvas size as the input")
    bounds = bounds_image.getchannel("A").getbbox()
    if bounds is None:
        raise SystemExit("input contains no visible pixels")

    marker = image.crop(bounds)
    scale = min(args.max_width / marker.width, args.max_height / marker.height)
    size = (
        max(1, round(marker.width * scale)),
        max(1, round(marker.height * scale)),
    )
    marker = marker.resize(size, Image.Resampling.LANCZOS)
    original_alpha_max = marker.getchannel("A").getextrema()[1]
    if args.normalize_alpha_max and 0 < original_alpha_max < 255:
        alpha_scale = 255.0 / original_alpha_max
        marker.putalpha(
            marker.getchannel("A").point(
                lambda value: min(255, round(value * alpha_scale))
            )
        )

    canvas = Image.new("RGBA", (args.canvas, args.canvas), (0, 0, 0, 0))
    position = ((args.canvas - marker.width) // 2, (args.canvas - marker.height) // 2)
    canvas.alpha_composite(marker, position)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output, optimize=True)
    print(
        f"normalized {args.input} -> {args.output}; "
        f"source_bbox={bounds}; marker={marker.width}x{marker.height}; "
        f"canvas={args.canvas}x{args.canvas}; alpha_max={original_alpha_max}"
        + ("->255" if args.normalize_alpha_max else "")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
