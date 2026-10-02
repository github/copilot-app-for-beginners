#!/usr/bin/env python3
"""Add ordered step callouts, highlight boxes, and arrows to a course screenshot.

Step badges mark two or more controls that the reader selects in order.
Highlight boxes outline one screen area that the nearby text points to, such
as a search field or terminal output. Arrows point at one small status or
control that the nearby text names. All use the course callout color.
"""

from __future__ import annotations

import argparse
import math
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
BOX_STROKE = 4
ARROW_STROKE = 5
ARROW_HEAD_LENGTH = 22
ARROW_HEAD_WIDTH = 22
ARROW_SUPERSAMPLE = 4
CALLOUT_PATTERN = re.compile(r"([1-9][0-9]*):([0-9]+):([0-9]+)")
BOX_PATTERN = re.compile(r"([0-9]+):([0-9]+):([0-9]+):([0-9]+)")


def parse_callout(value: str) -> tuple[int, int, int]:
    match = CALLOUT_PATTERN.fullmatch(value)
    if not match:
        raise argparse.ArgumentTypeError(
            "Callouts must use NUMBER:X:Y with positive integer values."
        )
    return tuple(int(part) for part in match.groups())


def parse_box(value: str) -> tuple[int, int, int, int]:
    match = BOX_PATTERN.fullmatch(value)
    if not match:
        raise argparse.ArgumentTypeError(
            "Boxes must use LEFT:TOP:RIGHT:BOTTOM with integer pixel values."
        )
    left, top, right, bottom = (int(part) for part in match.groups())
    if right <= left or bottom <= top:
        raise argparse.ArgumentTypeError("A box needs RIGHT > LEFT and BOTTOM > TOP.")
    return left, top, right, bottom


def parse_arrow(value: str) -> tuple[int, int, int, int]:
    match = BOX_PATTERN.fullmatch(value)
    if not match:
        raise argparse.ArgumentTypeError(
            "Arrows must use TAIL_X:TAIL_Y:HEAD_X:HEAD_Y with integer pixel values."
        )
    tail_x, tail_y, head_x, head_y = (int(part) for part in match.groups())
    if math.hypot(head_x - tail_x, head_y - tail_y) < ARROW_HEAD_LENGTH * 2:
        raise argparse.ArgumentTypeError(
            f"An arrow must be at least {ARROW_HEAD_LENGTH * 2}px long."
        )
    return tail_x, tail_y, head_x, head_y


def draw_arrow(
    output: Image.Image, tail_x: int, tail_y: int, head_x: int, head_y: int
) -> None:
    # Draw at a larger scale and shrink, so the arrow head has smooth edges.
    scale = ARROW_SUPERSAMPLE
    pad = ARROW_HEAD_WIDTH
    left = min(tail_x, head_x) - pad
    top = min(tail_y, head_y) - pad
    right = max(tail_x, head_x) + pad
    bottom = max(tail_y, head_y) + pad
    length = math.hypot(head_x - tail_x, head_y - tail_y)
    unit_x = (head_x - tail_x) / length
    unit_y = (head_y - tail_y) / length
    base_x = head_x - unit_x * ARROW_HEAD_LENGTH
    base_y = head_y - unit_y * ARROW_HEAD_LENGTH
    half = ARROW_HEAD_WIDTH / 2

    def scaled(x: float, y: float) -> tuple[float, float]:
        return (x - left) * scale, (y - top) * scale

    overlay = Image.new(
        "RGBA", ((right - left) * scale, (bottom - top) * scale), (0, 0, 0, 0)
    )
    draw = ImageDraw.Draw(overlay)
    draw.line(
        (scaled(tail_x, tail_y), scaled(base_x + unit_x, base_y + unit_y)),
        fill=BADGE_COLOR,
        width=ARROW_STROKE * scale,
    )
    draw.polygon(
        (
            scaled(head_x, head_y),
            scaled(base_x - unit_y * half, base_y + unit_x * half),
            scaled(base_x + unit_y * half, base_y - unit_x * half),
        ),
        fill=BADGE_COLOR,
    )
    overlay = overlay.resize((right - left, bottom - top), Image.LANCZOS)
    output.paste(overlay, (left, top), overlay)


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
        default=[],
        type=parse_callout,
        metavar="NUMBER:X:Y",
        help="Add one badge at final 1920x1080 pixel coordinates.",
    )
    parser.add_argument(
        "--box",
        action="append",
        default=[],
        type=parse_box,
        metavar="LEFT:TOP:RIGHT:BOTTOM",
        help="Outline one area at final 1920x1080 pixel coordinates.",
    )
    parser.add_argument(
        "--arrow",
        action="append",
        default=[],
        type=parse_arrow,
        metavar="TAIL_X:TAIL_Y:HEAD_X:HEAD_Y",
        help="Add one arrow that points at HEAD, at final 1920x1080 pixel coordinates.",
    )
    parser.add_argument(
        "--radius",
        type=int,
        help="Badge radius. Defaults to 26px at 1920px wide and scales down.",
    )
    args = parser.parse_args()

    if not args.callout and not args.box and not args.arrow:
        raise SystemExit("Add at least one --callout, --box, or --arrow.")
    if len(args.callout) == 1:
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
    if numbers and numbers != list(range(1, len(numbers) + 1)):
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
    for left, top, right, bottom in args.box:
        if not (
            BOX_STROKE <= left
            and BOX_STROKE <= top
            and right < image_size[0] - BOX_STROKE
            and bottom < image_size[1] - BOX_STROKE
        ):
            raise SystemExit(
                f"Box {left},{top},{right},{bottom} overlaps or exceeds the image border."
            )
        draw.rectangle(
            (left, top, right, bottom), outline=BADGE_COLOR, width=BOX_STROKE
        )

    margin = ARROW_HEAD_WIDTH + 2
    for tail_x, tail_y, head_x, head_y in args.arrow:
        if not all(
            margin <= x < image_size[0] - margin and margin <= y < image_size[1] - margin
            for x, y in ((tail_x, tail_y), (head_x, head_y))
        ):
            raise SystemExit(
                f"Arrow {tail_x},{tail_y},{head_x},{head_y} overlaps or exceeds the image border."
            )
        draw_arrow(output, tail_x, tail_y, head_x, head_y)

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
