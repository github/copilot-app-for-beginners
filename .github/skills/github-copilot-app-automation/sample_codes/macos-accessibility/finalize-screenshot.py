#!/usr/bin/env python3
"""Normalize a course screenshot and add its required inside border.

Default mode resizes a 16:9 capture to exactly 1920x1080 and adds a 2px
#cccccc border inside the image edges.

With --crop LEFT:TOP:RIGHT:BOTTOM, the input must already be a finalized
1920x1080 screenshot. The script cuts out that area (in 1920x1080 pixel
coordinates) for a detail image and adds the same 2px border to the crop.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw


TARGET_SIZE = (1920, 1080)
BORDER_COLOR = (204, 204, 204)
BORDER_WIDTH = 2
MINIMUM_CROP = (200, 100)
CROP_PATTERN = re.compile(r"([0-9]+):([0-9]+):([0-9]+):([0-9]+)")


def parse_crop(value: str) -> tuple[int, int, int, int]:
    match = CROP_PATTERN.fullmatch(value)
    if not match:
        raise argparse.ArgumentTypeError(
            "Crops must use LEFT:TOP:RIGHT:BOTTOM with integer pixel values."
        )
    left, top, right, bottom = (int(part) for part in match.groups())
    if right - left < MINIMUM_CROP[0] or bottom - top < MINIMUM_CROP[1]:
        raise argparse.ArgumentTypeError(
            f"A crop must be at least {MINIMUM_CROP[0]}x{MINIMUM_CROP[1]} pixels."
        )
    return left, top, right, bottom


def add_border(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    for offset in range(BORDER_WIDTH):
        draw.rectangle(
            (offset, offset, image.width - 1 - offset, image.height - 1 - offset),
            outline=BORDER_COLOR,
        )


def verify(path: Path, expected: tuple[int, int]) -> None:
    with Image.open(path) as verified:
        if verified.size != expected:
            raise SystemExit(
                f"{path} is {verified.width}x{verified.height}; "
                f"expected {expected[0]}x{expected[1]}."
            )
        pixels = verified.convert("RGB")
        for point in (
            (0, 0),
            (1, 1),
            (expected[0] - 1, expected[1] - 1),
            (expected[0] - 2, expected[1] - 2),
        ):
            if pixels.getpixel(point) != BORDER_COLOR:
                raise SystemExit(f"{path} does not have the required border.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument(
        "--crop",
        type=parse_crop,
        metavar="LEFT:TOP:RIGHT:BOTTOM",
        help="Cut a detail area out of a finalized 1920x1080 screenshot.",
    )
    args = parser.parse_args()

    if args.crop:
        left, top, right, bottom = args.crop
        with Image.open(args.image) as source:
            if source.size != TARGET_SIZE:
                raise SystemExit("Crop only a finalized 1920x1080 screenshot.")
            if right > TARGET_SIZE[0] or bottom > TARGET_SIZE[1]:
                raise SystemExit("The crop area must be inside the 1920x1080 image.")
            output = source.convert("RGB").crop((left, top, right, bottom))
        add_border(output)
        output.save(args.image)
        verify(args.image, output.size)
        return

    with Image.open(args.image) as source:
        source_ratio = source.width / source.height
        target_ratio = TARGET_SIZE[0] / TARGET_SIZE[1]
        if abs(source_ratio - target_ratio) > 0.01:
            raise SystemExit(
                f"Capture must be 16:9 before 1080p conversion; got "
                f"{source.width}x{source.height}."
            )
        # Standard windows have transparent rounded corners. Flatten them onto
        # white so the corners do not turn black in the RGB output.
        rgba = source.convert("RGBA")
        flattened = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
        flattened.alpha_composite(rgba)
        output = flattened.convert("RGB")
        if output.size != TARGET_SIZE:
            output = output.resize(TARGET_SIZE, Image.Resampling.LANCZOS)

    add_border(output)
    output.save(args.image)
    verify(args.image, TARGET_SIZE)


if __name__ == "__main__":
    main()
