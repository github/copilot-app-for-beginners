#!/usr/bin/env python3
"""Remove the macOS window buttons from a finalized course screenshot.

The three round window buttons (close, minimize, zoom) in the top-left corner
show that the screenshot comes from macOS. This script removes them and moves
the sidebar toggle icon that follows them to the place of the first button, so
the screenshot does not show the operating system.

The script finds the buttons from the pixels: three round controls of the same
size with equal gaps, followed by the sidebar icon. If it cannot find that
layout, it stops and does not change the image.

Usage:
  hide-window-controls.py <finalized_1920x1080_png>
"""

from __future__ import annotations

import sys
from pathlib import Path
from statistics import median

from PIL import Image

BAND = (10, 52)  # Rows that contain the title bar controls.
SEARCH = (8, 200)  # Columns to search, from the left edge of the window.
INK = 18  # Minimum color difference from the background.


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("Usage: hide-window-controls.py <finalized_1920x1080_png>")
    path = Path(sys.argv[1])
    image = Image.open(path).convert("RGB")
    pixels = image.load()
    rows = range(*BAND)
    columns = range(*SEARCH)

    background = {
        y: tuple(int(median(pixels[x, y][c] for x in columns)) for c in range(3))
        for y in rows
    }

    def is_ink(x: int, y: int) -> bool:
        return sum(abs(pixels[x, y][c] - background[y][c]) for c in range(3)) > INK

    clusters: list[list[int]] = []
    for x in columns:
        if any(is_ink(x, y) for y in rows):
            if clusters and x - clusters[-1][1] <= 3:
                clusters[-1][1] = x
            else:
                clusters.append([x, x])

    if len(clusters) < 4:
        fail(f"{path}: the window buttons were not found. The image was not changed.")
    buttons, icon = clusters[:3], clusters[3]
    widths = [right - left for left, right in buttons]
    gaps = [buttons[1][0] - buttons[0][0], buttons[2][0] - buttons[1][0]]
    if max(widths) - min(widths) > 3 or abs(gaps[0] - gaps[1]) > 3 or not 8 <= widths[0] <= 30:
        fail(f"{path}: the top-left controls do not look like window buttons. The image was not changed.")

    icon_rows = [y for y in rows if any(is_ink(x, y) for x in range(icon[0], icon[1] + 1))]
    top, bottom = icon_rows[0] - 1, icon_rows[-1] + 2
    left, right = icon[0] - 1, icon[1] + 2
    icon_image = image.crop((left, top, right, bottom))

    # Clear the buttons and the old icon with the background of each row.
    clear_left, clear_right = buttons[0][0] - 2, icon[1] + 3
    for y in rows:
        for x in range(clear_left, clear_right):
            pixels[x, y] = background[y]

    image.paste(icon_image, (buttons[0][0] - 1, top))
    image.save(path)
    print(f"window buttons removed; sidebar icon moved from x={icon[0]} to x={buttons[0][0]}")


if __name__ == "__main__":
    main()
