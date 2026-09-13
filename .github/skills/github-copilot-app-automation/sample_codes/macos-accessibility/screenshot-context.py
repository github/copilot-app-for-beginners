#!/usr/bin/env python3
"""Print the Markdown context that defines one screenshot's required state."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


IMAGE_PATTERNS = (
    re.compile(r"!\[[^\]]*\]\(([^)]+)\)"),
    re.compile(r"""<img\b[^>]*\bsrc=["']([^"']+)["'][^>]*>""", re.IGNORECASE),
)
HEADING_PATTERN = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("markdown", type=Path)
    parser.add_argument("image")
    args = parser.parse_args()

    lines = args.markdown.read_text(encoding="utf-8").splitlines()
    matches = []
    for index, line in enumerate(lines):
        for image_pattern in IMAGE_PATTERNS:
            for image_match in image_pattern.finditer(line):
                target = image_match.group(1)
                if target == args.image or Path(target).name == Path(args.image).name:
                    matches.append((index, target))

    if len(matches) != 1:
        raise SystemExit(
            f"Expected one reference to {args.image!r}, found {len(matches)}."
        )

    image_index, image_target = matches[0]
    section_start = 0
    heading_level = 6
    heading_text = "(document start)"
    for index in range(image_index, -1, -1):
        heading_match = HEADING_PATTERN.match(lines[index])
        if heading_match:
            section_start = index
            heading_level = len(heading_match.group(1))
            heading_text = heading_match.group(2)
            break

    section_end = len(lines)
    for index in range(image_index + 1, len(lines)):
        heading_match = HEADING_PATTERN.match(lines[index])
        if heading_match and len(heading_match.group(1)) <= heading_level:
            section_end = index
            break

    context_start = max(section_start, image_index - 12)
    context_end = min(section_end, image_index + 13)
    print(f"source={args.markdown}")
    print(f"image={image_target}")
    print(f"reference_line={image_index + 1}")
    print(f"section={heading_text}")
    print("--- context ---")
    for index in range(context_start, context_end):
        marker = ">" if index == image_index else " "
        print(f"{marker} {index + 1}: {lines[index]}")


if __name__ == "__main__":
    main()
