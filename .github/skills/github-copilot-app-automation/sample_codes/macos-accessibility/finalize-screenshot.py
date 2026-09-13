#!/usr/bin/env python3
"""Normalize a course screenshot and add its required inside border."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


TARGET_SIZE = (1920, 1080)
BORDER_COLOR = (204, 204, 204)
BORDER_WIDTH = 2


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    args = parser.parse_args()

    with Image.open(args.image) as source:
        source_ratio = source.width / source.height
        target_ratio = TARGET_SIZE[0] / TARGET_SIZE[1]
        if abs(source_ratio - target_ratio) > 0.01:
            raise SystemExit(
                f"Capture must be 16:9 before 1080p conversion; got "
                f"{source.width}x{source.height}."
            )
        output = source.convert("RGB").resize(TARGET_SIZE, Image.Resampling.LANCZOS)

    draw = ImageDraw.Draw(output)
    for offset in range(BORDER_WIDTH):
        draw.rectangle(
            (
                offset,
                offset,
                TARGET_SIZE[0] - 1 - offset,
                TARGET_SIZE[1] - 1 - offset,
            ),
            outline=BORDER_COLOR,
        )
    output.save(args.image)

    with Image.open(args.image) as verified:
        if verified.size != TARGET_SIZE:
            raise SystemExit(
                f"{args.image} is {verified.width}x{verified.height}; "
                "expected 1920x1080."
            )
        pixels = verified.convert("RGB")
        for point in (
            (0, 0),
            (1, 1),
            (TARGET_SIZE[0] - 1, TARGET_SIZE[1] - 1),
            (TARGET_SIZE[0] - 2, TARGET_SIZE[1] - 2),
        ):
            if pixels.getpixel(point) != BORDER_COLOR:
                raise SystemExit(f"{args.image} does not have the required border.")


if __name__ == "__main__":
    main()
