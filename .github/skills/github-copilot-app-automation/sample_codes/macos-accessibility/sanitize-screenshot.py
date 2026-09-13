#!/usr/bin/env python3
"""Replace personal identity text in a screenshot while preserving avatars."""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SAFE_DISPLAY_NAME = "Copilot Dev"
SAFE_OWNER = "copilotdev"
VERSION_PATTERN = re.compile(r"(?i)\bv?\d+[.,]\d+[.,]\d+(?:[-+][a-z0-9.-]+)?\b")
FONT_CANDIDATES = (
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
)


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def normalize(value: str) -> str:
    return "".join(character for character in value.casefold() if character.isalnum())


def ocr_words(image_path: Path) -> list[dict[str, object]]:
    image_path = image_path.resolve()
    result = subprocess.run(
        ["tesseract", str(image_path), "stdout", "--psm", "11", "tsv"],
        check=True,
        capture_output=True,
        text=True,
        errors="replace",
    )
    words: list[dict[str, object]] = []
    for row in csv.DictReader(io.StringIO(result.stdout), delimiter="\t"):
        text = row.get("text", "").strip()
        try:
            confidence = float(row.get("conf", "-1"))
        except ValueError:
            confidence = -1
        if not text or confidence < 20:
            continue
        words.append(
            {
                "text": text,
                "left": int(row["left"]),
                "top": int(row["top"]),
                "width": int(row["width"]),
                "height": int(row["height"]),
                "line": (
                    row["page_num"],
                    row["block_num"],
                    row["par_num"],
                    row["line_num"],
                ),
            }
        )
    return words


def phrase_matches(
    words: list[dict[str, object]], phrase: str
) -> list[tuple[list[dict[str, object]], str]]:
    expected = [normalize(part) for part in phrase.split() if normalize(part)]
    if not expected:
        return []

    matches: list[tuple[list[dict[str, object]], str]] = []
    for index in range(len(words) - len(expected) + 1):
        candidate = words[index : index + len(expected)]
        if len({word["line"] for word in candidate}) != 1:
            continue
        actual = [normalize(str(word["text"])) for word in candidate]
        if actual == expected:
            matches.append((candidate, SAFE_DISPLAY_NAME))
    return matches


def owner_matches(
    words: list[dict[str, object]], owner: str
) -> list[tuple[list[dict[str, object]], str]]:
    matches: list[tuple[list[dict[str, object]], str]] = []
    owner_pattern = re.compile(re.escape(owner), re.IGNORECASE)
    for word in words:
        text = str(word["text"])
        if normalize(owner) not in normalize(text):
            continue
        if normalize(text) == normalize(owner):
            matches.append(([word], SAFE_OWNER))
            continue
        if "/" not in text:
            continue
        replacement = owner_pattern.sub(SAFE_OWNER, text)
        if replacement == text:
            slash_index = text.find("/")
            replacement = SAFE_OWNER + text[slash_index:]
        matches.append(([word], replacement))
    return matches


def is_settings_screen(words: list[dict[str, object]]) -> bool:
    values = {normalize(str(word["text"])) for word in words}
    required = {"general", "accounts", "sessions"}
    supporting = {"themes", "accessibility", "voicedictation", "experimental"}
    return required.issubset(values) and len(values.intersection(supporting)) >= 2


def settings_version_matches(
    words: list[dict[str, object]],
) -> list[tuple[list[dict[str, object]], str]]:
    matches: list[tuple[list[dict[str, object]], str]] = []
    if not is_settings_screen(words):
        return matches
    for word in words:
        text = str(word["text"])
        if not VERSION_PATTERN.search(text):
            continue
        matches.append(([word], VERSION_PATTERN.sub("", text).strip()))
    return matches


def bounds(match: list[dict[str, object]]) -> tuple[int, int, int, int]:
    left = min(int(word["left"]) for word in match)
    top = min(int(word["top"]) for word in match)
    right = max(int(word["left"]) + int(word["width"]) for word in match)
    bottom = max(int(word["top"]) + int(word["height"]) for word in match)
    return left, top, right, bottom


def background_color(
    image: Image.Image, box: tuple[int, int, int, int]
) -> tuple[int, int, int]:
    left, top, right, bottom = box
    padding = max(4, (bottom - top) // 3)
    outer = image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    ).convert("RGB")
    inner_left = max(0, left - max(0, left - padding))
    inner_top = max(0, top - max(0, top - padding))
    inner_right = inner_left + (right - left)
    inner_bottom = inner_top + (bottom - top)
    pixels = []
    for y in range(outer.height):
        for x in range(outer.width):
            if inner_left <= x < inner_right and inner_top <= y < inner_bottom:
                continue
            pixels.append(outer.getpixel((x, y)))
    if not pixels:
        pixels = list(outer.getdata())
    quantized = [
        tuple((channel // 8) * 8 for channel in pixel)
        for pixel in pixels
    ]
    common = Counter(quantized).most_common(1)[0][0]
    close_pixels = [
        pixel
        for pixel in pixels
        if sum(abs(pixel[index] - common[index]) for index in range(3)) <= 24
    ]
    source = close_pixels or pixels
    return tuple(
        int(sum(pixel[index] for pixel in source) / len(source))
        for index in range(3)
    )


def text_color(
    image: Image.Image, box: tuple[int, int, int, int]
) -> tuple[int, int, int]:
    pixels = list(image.crop(box).convert("RGB").getdata())
    pixels.sort(key=lambda pixel: sum(pixel))
    darkest = pixels[: max(1, len(pixels) // 12)]
    return tuple(
        int(sum(pixel[index] for pixel in darkest) / len(darkest))
        for index in range(3)
    )


def font_for(text: str, width: int, height: int) -> ImageFont.FreeTypeFont:
    font_path = next((path for path in FONT_CANDIDATES if Path(path).is_file()), None)
    if font_path is None:
        fail("No supported system font was found.")
    draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    for size in range(max(8, height * 2), 7, -1):
        font = ImageFont.truetype(font_path, size)
        measured = draw.textbbox((0, 0), text, font=font)
        if measured[2] - measured[0] <= width and measured[3] - measured[1] <= height:
            return font
    return ImageFont.truetype(font_path, 8)


def replace_text(
    image: Image.Image,
    match: list[dict[str, object]],
    replacement: str,
) -> None:
    left, top, right, bottom = bounds(match)
    height = bottom - top
    horizontal_padding = max(4, height // 5)
    vertical_padding = max(3, height // 6)
    clear_box = (
        max(0, left - horizontal_padding),
        max(0, top - vertical_padding),
        min(image.width, right + horizontal_padding),
        min(image.height, bottom + vertical_padding),
    )
    background = background_color(image, clear_box)
    foreground = text_color(image, (left, top, right, bottom))
    draw = ImageDraw.Draw(image)
    draw.rectangle(clear_box, fill=background)

    if not replacement:
        return

    available_width = clear_box[2] - left - horizontal_padding
    available_height = clear_box[3] - clear_box[1] - (2 * vertical_padding)
    font = font_for(replacement, available_width, max(height, available_height))
    text_box = draw.textbbox((0, 0), replacement, font=font)
    text_height = text_box[3] - text_box[1]
    y = clear_box[1] + ((clear_box[3] - clear_box[1] - text_height) // 2) - text_box[1]
    draw.text((left, y), replacement, font=font, fill=foreground)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("identities", type=Path)
    args = parser.parse_args()

    identities = json.loads(args.identities.read_text())
    display_names = [
        name
        for name in identities.get("displayNames", [])
        if name.casefold() != SAFE_DISPLAY_NAME.casefold()
    ]
    owners = [
        owner
        for owner in identities.get("repositoryOwners", [])
        if owner.casefold() != SAFE_OWNER.casefold()
    ]
    account_names = [
        account
        for account in identities.get("accountNames", [])
        if account.casefold() != SAFE_OWNER.casefold()
    ]

    image = Image.open(args.input).convert("RGB")
    words = ocr_words(args.input)
    replacements: list[tuple[list[dict[str, object]], str, str]] = []

    for name in display_names:
        matches = phrase_matches(words, name)
        if not matches:
            fail(
                f"OCR did not locate visible profile name {name!r}. "
                "Keep the raw capture and review it manually."
            )
        replacements.extend(
            (match, replacement, "profile name")
            for match, replacement in matches
        )

    for owner in owners:
        matches = owner_matches(words, owner)
        replacements.extend(
            (match, replacement, "repository owner")
            for match, replacement in matches
        )

    for account in account_names:
        matches = owner_matches(words, account)
        replacements.extend(
            (match, replacement, "account handle")
            for match, replacement in matches
        )

    replacements.extend(
        (match, replacement, "Settings version")
        for match, replacement in settings_version_matches(words)
    )

    seen_boxes: set[tuple[int, int, int, int]] = set()
    applied: list[str] = []
    for match, replacement, identity_type in replacements:
        box = bounds(match)
        if box in seen_boxes:
            continue
        seen_boxes.add(box)
        replace_text(image, match, replacement)
        applied.append(f"{identity_type} -> {replacement}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)

    remaining_words = ocr_words(args.output)
    remaining_text = " ".join(str(word["text"]) for word in remaining_words)
    for source in [*display_names, *owners, *account_names]:
        if normalize(source) in normalize(remaining_text):
            fail(
                f"Sanitization verification found identity text {source!r} "
                "in the output image."
            )
    if is_settings_screen(remaining_words) and VERSION_PATTERN.search(remaining_text):
        fail("Sanitization verification found an app version on the Settings screen.")

    print(f"sanitized={args.output}")
    print(f"replacements={len(applied)}")
    for replacement in applied:
        print(f"  {replacement}")


if __name__ == "__main__":
    main()
