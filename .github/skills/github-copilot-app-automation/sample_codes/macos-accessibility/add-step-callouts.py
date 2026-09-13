#!/usr/bin/env python3
"""Add ordered step callouts to a course screenshot."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BADGE_COLOR = "#ff594b"
TEXT_COLOR = "#ffffff"
REFERENCE_WIDTH = 1920
REFERENCE_RADIUS = 26
FONT_CANDIDATES = (
    ("/System/Library/Fonts/Helvetica.ttc", 1),
    ("/System/Library/Fonts/SFNS.ttf", 0),
    ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
)
CALLOUT_PATTERN = re.compile(r"([1-9][0-9]*):([0-9]+):([0-9]+)")


def parse_callout(value: str) -> tuple[int, int, int]:
    match = CALLOUT_PATTERN.fullmatch(value)
    if not match:
        raise argparse.ArgumentTypeError(
            "Callouts must use NUMBER:X:Y with positive integer values."
        )
    return tuple(int(part) for part in match.groups())


def load_font(radius: int) -> ImageFont.FreeTypeFont:
    size = round(radius * 1.35)
    for path, index in FONT_CANDIDATES:
        if Path(path).is_file():
            return ImageFont.truetype(path, size, index=index)
    raise SystemExit("No supported system font was found.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument(
        "--callout",
        action="append",
        required=True,
        type=parse_callout,
        metavar="NUMBER:X:Y",
        help="Add one badge at final 1920x1080 pixel coordinates.",
    )
    parser.add_argument(
        "--radius",
        type=int,
        help="Badge radius. Defaults to 26px at 1920px wide and scales down.",
    )
    args = parser.parse_args()

    if len(args.callout) < 2:
        raise SystemExit(
            "Use step callouts only when one screenshot shows two or more actions."
        )
    with Image.open(args.image) as source:
        output = source.convert("RGB")
        image_size = source.size

    radius = args.radius or max(
        12, round(REFERENCE_RADIUS * image_size[0] / REFERENCE_WIDTH)
    )
    if radius < 12 or radius > 60:
        raise SystemExit("Radius must be between 12 and 60 pixels.")
    numbers = [number for number, _, _ in args.callout]
    if numbers != list(range(1, len(numbers) + 1)):
        raise SystemExit("Callout numbers must be ordered and consecutive from 1.")

    for number, x, y in args.callout:
        if not (
            radius + 2 <= x < image_size[0] - radius - 2
            and radius + 2 <= y < image_size[1] - radius - 2
        ):
            raise SystemExit(
                f"Callout {number} at {x},{y} overlaps or exceeds the image border."
            )

    draw = ImageDraw.Draw(output)
    font = load_font(radius)
    for number, x, y in args.callout:
        draw.ellipse(
            (
                x - radius,
                y - radius,
                x + radius,
                y + radius,
            ),
            fill=BADGE_COLOR,
        )
        label = str(number)
        bounds = draw.textbbox((0, 0), label, font=font)
        text_x = x - ((bounds[2] - bounds[0]) / 2) - bounds[0]
        text_y = y - ((bounds[3] - bounds[1]) / 2) - bounds[1]
        draw.text((text_x, text_y), label, font=font, fill=TEXT_COLOR)

    save_options = {}
    if args.image.suffix.casefold() == ".webp":
        save_options = {"lossless": True, "quality": 100, "method": 6}
    output.save(args.image, **save_options)


if __name__ == "__main__":
    main()
