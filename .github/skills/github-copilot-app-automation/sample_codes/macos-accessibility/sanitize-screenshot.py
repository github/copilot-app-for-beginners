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
import tempfile
from collections import Counter
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SAFE_DISPLAY_NAME = "Copilot Dev"
SAFE_OWNER = "copilotdev"
# A machine name is private (it often includes the owner's first name). Shell
# prompts, terminal output, and paths can show it, so it becomes this value.
SAFE_HOST = "copilot-dev-mac"
# Small UI text is hard for Tesseract to read at 1x. OCR runs on a grayscale
# copy at this scale, and word boxes are mapped back to the source image.
OCR_SCALE = 3
VERSION_PATTERN = re.compile(r"(?i)\bv?\d+[.,]\d+[.,]\d+(?:[-+][a-z0-9.-]+)?\b")
# Fonts used to redraw replaced text. The app draws its interface in the macOS
# system font (SF Pro), and paths and terminal output in SF Mono. Each word uses
# the family that best matches its measured width; the fallbacks are used only
# when the system fonts are missing.
UI_FONT = "/System/Library/Fonts/SFNS.ttf"
MONO_FONT = "/System/Library/Fonts/SFNSMono.ttf"
FALLBACK_FONTS = (
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Menlo.ttc",
)
FONT_CANDIDATES = (UI_FONT, MONO_FONT, *FALLBACK_FONTS)
# A pixel is text ("ink") when its color differs this much from the background.
INK_THRESHOLD = 90


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def normalize(value: str) -> str:
    return "".join(character for character in value.casefold() if character.isalnum())


def as_drawn(text: str) -> str:
    """Return OCR text as the app draws it, for width calculations.

    The app shortens long labels with one ellipsis glyph, which OCR reads as
    "..." (three periods). In a monospace font the periods take three cells but
    the glyph takes one, so widths measured from the OCR text put a private span
    up to two characters too far left. OCR also often reads "-" as an en dash
    or em dash, which are much wider in a proportional font. Each change keeps
    one character for one character (the periods are at the end), so the
    indexes of all other characters stay the same.
    """
    text = text.translate(str.maketrans({"\u2013": "-", "\u2014": "-"}))
    return re.sub(r"\.{2,}$", "\u2026", text)


def opaque(image: Image.Image) -> Image.Image:
    """Flatten transparent window corners onto white."""
    rgba = image.convert("RGBA")
    background = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
    background.alpha_composite(rgba)
    return background.convert("RGB")


def edit_distance(first: str, second: str) -> int:
    previous = list(range(len(second) + 1))
    for row, first_character in enumerate(first, start=1):
        current = [row]
        for column, second_character in enumerate(second, start=1):
            current.append(
                min(
                    previous[column] + 1,
                    current[column - 1] + 1,
                    previous[column - 1] + (first_character != second_character),
                )
            )
        previous = current
    return previous[-1]


def similar(actual: str, expected: str) -> bool:
    """Match an OCR word, allowing one misread letter in longer words."""
    if actual == expected:
        return True
    return len(expected) >= 5 and edit_distance(actual, expected) <= 1


def approximate_span(text: str, target: str) -> tuple[int, int] | None:
    """Find target in text, allowing one misread letter in longer values.

    Returns the start and end index in text, or None. The comparison ignores
    letter case. OCR often misreads one letter in small UI text, such as "l"
    as "i", so an exact search alone can miss private text.
    """
    # OCR often reads a hyphen as an en dash or em dash. Map those to "-" so
    # names such as "My-MacBook-Pro" still match. The mapping keeps every
    # character in place, so the returned indexes still apply to the input.
    dashes = str.maketrans({"\u2010": "-", "\u2011": "-", "\u2012": "-", "\u2013": "-", "\u2014": "-", "\u2212": "-"})
    lowered = text.casefold().translate(dashes)
    wanted = target.casefold().translate(dashes)
    exact = lowered.find(wanted)
    if exact >= 0:
        return exact, exact + len(wanted)
    if len(wanted) < 5:
        return None
    # The app shortens long labels with an ellipsis ("danwahl..."). A word that
    # ends in an ellipsis after a long enough prefix of the target is private.
    # OCR can read the ellipsis as two or three periods and can misread one
    # letter of the prefix (for example "l" as "1"), so a prefix of six or more
    # characters can differ by one edit. Every shortened word is checked, and
    # the best-matching start is used so that a separator such as "-" before
    # the name stays. The span ends before the ellipsis, so the replacement
    # keeps the "..." that shows the label is shortened.
    for truncated in re.finditer(r"([A-Za-z0-9_.-]+?)(?:\.{2,}|\u2026)", lowered):
        stem = truncated.group(1)
        start = truncated.start(1)
        candidates: list[tuple[int, bool, int, int]] = []
        for offset in range(len(stem)):
            piece = stem[offset:]
            if len(piece) < 5 or len(piece) > len(wanted) + 1:
                continue
            if len(piece) < 6:
                distance = 0 if wanted.startswith(piece) else 2
            else:
                distance = min(
                    edit_distance(piece, wanted[:length])
                    for length in (len(piece) - 1, len(piece), len(piece) + 1)
                    if 0 < length <= len(wanted)
                )
            if distance <= 1:
                candidates.append((distance, piece[0] != wanted[0], -len(piece), offset))
        if candidates:
            offset = min(candidates)[3]
            return start + offset, truncated.end(1)
    best: tuple[int, int, int] | None = None
    for length in (len(wanted) - 1, len(wanted), len(wanted) + 1):
        for start in range(0, len(lowered) - length + 1):
            distance = edit_distance(lowered[start : start + length], wanted)
            if distance <= 1 and (best is None or distance < best[0]):
                best = (distance, start, start + length)
    return (best[1], best[2]) if best else None


# Verification reads the image again with different settings, because one OCR
# pass can miss a word that another pass finds.
VERIFY_PASSES = ((OCR_SCALE, "11"), (4, "6"))


def ocr_words(
    image_path: Path, scale: int = OCR_SCALE, psm: str = "11"
) -> list[dict[str, object]]:
    with Image.open(image_path.resolve()) as source:
        grayscale = opaque(source).convert("L")
        scaled = grayscale.resize(
            (grayscale.width * scale, grayscale.height * scale),
            Image.Resampling.LANCZOS,
        )
    with tempfile.TemporaryDirectory() as temporary_directory:
        scaled_path = Path(temporary_directory) / "ocr.png"
        scaled.save(scaled_path)
        result = subprocess.run(
            ["tesseract", str(scaled_path), "stdout", "--psm", psm, "tsv"],
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
        left = int(row["left"]) // scale
        top = int(row["top"]) // scale
        right = -(-(int(row["left"]) + int(row["width"])) // scale)
        bottom = -(-(int(row["top"]) + int(row["height"])) // scale)
        words.append(
            {
                "text": text,
                "left": left,
                "top": top,
                "width": right - left,
                "height": bottom - top,
                "line": (
                    row["page_num"],
                    row["block_num"],
                    row["par_num"],
                    row["line_num"],
                ),
            }
        )
    return words


@dataclass
class Replacement:
    """One private text span inside one OCR word or phrase."""

    words: list[dict[str, object]]
    original: str
    start: int
    end: int
    new: str
    kind: str


@dataclass
class Geometry:
    """Measured pixel extents of a word in the image."""

    left: int
    right: int
    top: int
    bottom: int
    baseline: int
    neighbor_left: int


def phrase_matches(
    words: list[dict[str, object]], phrase: str
) -> list[list[dict[str, object]]]:
    expected = [normalize(part) for part in phrase.split() if normalize(part)]
    if not expected:
        return []

    matches: list[list[dict[str, object]]] = []
    for index in range(len(words) - len(expected) + 1):
        candidate = words[index : index + len(expected)]
        if len({word["line"] for word in candidate}) != 1:
            continue
        actual = [normalize(str(word["text"])) for word in candidate]
        if all(similar(word, part) for word, part in zip(actual, expected)):
            matches.append(candidate)
    return matches


def is_settings_screen(words: list[dict[str, object]]) -> bool:
    values = {normalize(str(word["text"])) for word in words}
    required = {"general", "accounts", "sessions"}
    supporting = {"themes", "accessibility", "voicedictation", "experimental"}
    return required.issubset(values) and len(values.intersection(supporting)) >= 2


def bounds(match: list[dict[str, object]]) -> tuple[int, int, int, int]:
    left = min(int(word["left"]) for word in match)
    top = min(int(word["top"]) for word in match)
    right = max(int(word["left"]) + int(word["width"]) for word in match)
    bottom = max(int(word["top"]) + int(word["height"]) for word in match)
    return left, top, right, bottom


def background_color(
    image: Image.Image, box: tuple[int, int, int, int]
) -> tuple[int, int, int]:
    """Return the most common color in a ring around the box.

    Uses the exact color, not an average, so a cleared area does not show as a
    slightly different patch against the surrounding background.
    """
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
    inner_left = left - max(0, left - padding)
    inner_top = top - max(0, top - padding)
    inner_right = inner_left + (right - left)
    inner_bottom = inner_top + (bottom - top)
    pixels = [
        outer.getpixel((x, y))
        for y in range(outer.height)
        for x in range(outer.width)
        if not (inner_left <= x < inner_right and inner_top <= y < inner_bottom)
    ]
    if not pixels:
        pixels = list(outer.getdata())
    return Counter(pixels).most_common(1)[0][0]


def is_ink(pixel: tuple[int, int, int], background: tuple[int, int, int]) -> bool:
    return sum(abs(int(pixel[index]) - background[index]) for index in range(3)) > INK_THRESHOLD


def text_color(
    image: Image.Image,
    box: tuple[int, int, int, int],
    background: tuple[int, int, int],
) -> tuple[int, int, int]:
    """Average the pixels that differ most from the background.

    This works for dark text on a light background and for light text on a
    dark background, such as terminal output.
    """
    pixels = list(image.crop(box).convert("RGB").getdata())
    if not pixels:
        return (0, 0, 0)
    pixels.sort(
        key=lambda pixel: sum(abs(pixel[index] - background[index]) for index in range(3)),
        reverse=True,
    )
    # The cores of the letters carry the true color. Edge pixels are blended
    # with the background, so use only the strongest few pixels.
    strongest = pixels[: max(1, len(pixels) // 40)]
    return tuple(
        int(sum(pixel[index] for pixel in strongest) / len(strongest)) for index in range(3)
    )


def measure(
    image: Image.Image,
    box: tuple[int, int, int, int],
    background: tuple[int, int, int],
) -> Geometry | None:
    """Measure the word's ink, baseline, and the next text to its right.

    OCR boxes can be one or two pixels too small or too large, so the word's
    real extent is found from its pixels. Glyphs inside a word are at most two
    empty columns apart. A wider gap ends the word, so separators such as "·"
    and the next word are not treated as part of it.
    """
    pixels = image.load()
    width, height = image.size
    left, top, right, bottom = box
    band_top = max(0, top - 2)
    band_bottom = min(height - 1, bottom + 2)

    def column_has_ink(x: int) -> bool:
        if x < 0 or x >= width:
            return False
        return any(is_ink(pixels[x, y], background) for y in range(band_top, band_bottom + 1))

    inside = [x for x in range(max(0, left), min(width, right + 1)) if column_has_ink(x)]
    if not inside:
        return None
    word_left, word_right = inside[0], inside[-1]
    x, empty = word_left, 0
    while x > 0 and empty < 3:
        x -= 1
        if column_has_ink(x):
            word_left, empty = x, 0
        else:
            empty += 1
    x, empty = word_right, 0
    while x < width - 1 and empty < 3:
        x += 1
        if column_has_ink(x):
            word_right, empty = x, 0
        else:
            empty += 1

    tops: list[int] = []
    bottoms: list[int] = []
    for x in range(word_left, word_right + 1):
        rows = [y for y in range(band_top, band_bottom + 1) if is_ink(pixels[x, y], background)]
        if rows:
            tops.append(rows[0])
            bottoms.append(rows[-1])
    if not tops:
        return None
    baseline = sorted(bottoms)[len(bottoms) // 2]

    neighbor_left = width
    for x in range(word_right + 1, min(width, word_right + 400)):
        if column_has_ink(x):
            neighbor_left = x
            break
    return Geometry(word_left, word_right, min(tops), max(bottoms), baseline, neighbor_left)


def weight_axes(path: str) -> bool:
    try:
        axes = ImageFont.truetype(path, 12).get_variation_axes()
    except (OSError, AttributeError):
        return False
    return any(
        (axis.get("name").decode() if isinstance(axis.get("name"), bytes) else str(axis.get("name")))
        == "Weight"
        for axis in axes
    )


@lru_cache(maxsize=4096)
def load_font(path: str, size: float, weight: float | None = None) -> ImageFont.FreeTypeFont:
    """Load a font and apply automatic optical sizing, as the app does.

    Variable system fonts have an "Optical Size" axis. Browsers set it to the
    font size, which selects wider letter spacing at small sizes. Without this,
    the default (large) optical size draws small text too tightly. Fonts are
    cached because font fitting loads many sizes. Do not change a returned font.
    """
    font = ImageFont.truetype(path, size)
    try:
        axes = font.get_variation_axes()
    except (OSError, AttributeError):
        return font
    values = []
    for axis in axes:
        name = axis.get("name", b"")
        name = name.decode() if isinstance(name, bytes) else str(name)
        if "optical" in name.casefold():
            values.append(min(max(size, axis["minimum"]), axis["maximum"]))
        elif name.casefold() == "weight" and weight is not None:
            values.append(min(max(weight, axis["minimum"]), axis["maximum"]))
        else:
            values.append(axis["default"])
    font.set_variation_by_axes(values)
    return font


def stem_width(
    image: Image.Image,
    geometry: Geometry,
    background: tuple[int, int, int],
    color: tuple[int, int, int],
) -> float:
    """Median width of vertical strokes, measured across the middle of the word."""
    pixels = image.load()
    full = sum(abs(color[index] - background[index]) for index in range(3)) or 1
    widths: list[int] = []
    for offset in (2, 3):
        y = geometry.baseline - (geometry.baseline - geometry.top) // offset
        run = 0
        for x in range(geometry.left, geometry.right + 2):
            strength = sum(abs(pixels[x, y][index] - background[index]) for index in range(3)) / full
            if strength >= 0.5:
                run += 1
            elif run:
                widths.append(run)
                run = 0
    # Ignore wide runs from horizontal strokes such as the bar of a "T".
    widths = sorted(width for width in widths if width <= 4)
    if not widths:
        return 1.0
    return sum(widths) / len(widths)


def rendered_stem_width(text: str, font: ImageFont.FreeTypeFont) -> float:
    left, top, right, bottom = font.getbbox(text, anchor="ls")
    width, height = max(1, right - left), max(1, -top)
    canvas = Image.new("L", (width + 2, height + 2), 0)
    ImageDraw.Draw(canvas).text((1 - left, 1 - top), text, font=font, fill=255, anchor="ls")
    widths: list[int] = []
    for offset in (2, 3):
        y = 1 + height - height // offset
        run = 0
        for x in range(canvas.width):
            if canvas.getpixel((x, y)) >= 128:
                run += 1
            elif run:
                widths.append(run)
                run = 0
    widths = sorted(width for width in widths if width <= 4)
    if not widths:
        return 1.0
    return sum(widths) / len(widths)


def calibrated_font(
    text: str,
    geometry: Geometry,
    image: Image.Image,
    background: tuple[int, int, int],
    color: tuple[int, int, int],
) -> ImageFont.FreeTypeFont:
    """Pick the family, size, and weight that best reproduce the original word.

    The family is the system font or the system monospace font, whichever
    reproduces the measured width better. The size matches the height from the
    baseline to the top of the tallest letter. The weight (regular or medium)
    matches the measured stroke width.
    """
    target_height = max(3, geometry.baseline - geometry.top + 1)
    target_width = max(3, geometry.right - geometry.left + 1)
    target_stem = stem_width(image, geometry, background, color)

    families = [path for path in (UI_FONT, MONO_FONT) if Path(path).is_file()]
    if not families:
        families = [path for path in FALLBACK_FONTS if Path(path).is_file()]
    if not families:
        fail("No supported system font was found.")

    def fit(path: str, weight: float | None) -> tuple[float, ImageFont.FreeTypeFont]:
        # The app zoom (for example, 175%) gives fractional pixel sizes, so try quarter
        # sizes. Whole sizes alone can miss the real size by enough to choose
        # the wrong family.
        best_fit: tuple[float, ImageFont.FreeTypeFont] | None = None
        smallest = max(6.0, int(target_height * 0.9))
        steps = int((target_height * 2.2 + 2 - smallest) * 4)
        for step in range(max(1, steps)):
            size = smallest + step / 4
            font = load_font(path, size, weight)
            box = font.getbbox(text, anchor="ls")
            glyph_height = -box[1]
            glyph_width = box[2] - box[0]
            if glyph_height <= 0 or glyph_width <= 0:
                continue
            score = (
                2 * abs(glyph_height - target_height) / target_height
                + abs(glyph_width - target_width) / target_width
            )
            if best_fit is None or score < best_fit[0]:
                best_fit = (score, font)
        if best_fit is None:
            return (float("inf"), load_font(path, max(6, target_height), weight))
        return best_fit

    # Choose the family with regular weight first, then choose the weight.
    family = min(families, key=lambda path: fit(path, 400 if weight_axes(path) else None)[0])
    if not weight_axes(family):
        return fit(family, None)[1]
    options = [fit(family, weight) for weight in (400, 500)]
    return min(
        options,
        key=lambda option: option[0]
        + 0.8 * abs(rendered_stem_width(text, option[1]) - target_stem) / max(target_stem, 1.0),
    )[1]


def ink_runs(
    image: Image.Image, geometry: Geometry, background: tuple[int, int, int]
) -> list[tuple[int, int]]:
    """Return (first, last) columns of each run of inked columns in the word."""
    pixels = image.load()
    runs: list[tuple[int, int]] = []
    start = None
    for x in range(geometry.left, geometry.right + 2):
        inked = x <= geometry.right and any(
            is_ink(pixels[x, y], background) for y in range(geometry.top, geometry.bottom + 1)
        )
        if inked and start is None:
            start = x
        elif not inked and start is not None:
            runs.append((start, x - 1))
            start = None
    return runs


def is_slash(
    image: Image.Image,
    run: tuple[int, int],
    geometry: Geometry,
    background: tuple[int, int, int],
) -> bool:
    """Check whether a glyph run looks like "/": ink rises from left to right."""
    pixels = image.load()
    tops: list[int] = []
    for x in range(run[0], run[1] + 1):
        rows = [y for y in range(geometry.top, geometry.bottom + 1) if is_ink(pixels[x, y], background)]
        if not rows:
            return False
        tops.append(rows[0])
    tall = geometry.bottom - geometry.top + 1
    return len(tops) >= 3 and tops[0] - tops[-1] >= tall // 2 and all(
        tops[i] >= tops[i + 1] for i in range(len(tops) - 1)
    )


def is_dot(
    image: Image.Image,
    run: tuple[int, int],
    geometry: Geometry,
    background: tuple[int, int, int],
) -> bool:
    """Check whether a glyph run looks like a period or an ellipsis dot."""
    pixels = image.load()
    rows = {
        y
        for x in range(run[0], run[1] + 1)
        for y in range(geometry.top, geometry.bottom + 1)
        if is_ink(pixels[x, y], background)
    }
    if not rows:
        return False
    tall = max(3, geometry.baseline - geometry.top + 1)
    return (
        min(rows) >= geometry.baseline - tall * 0.35
        and max(rows) <= geometry.baseline + 1
        and run[1] - run[0] + 1 <= max(3, round(tall * 0.6))
    )


def is_hyphen(
    image: Image.Image,
    run: tuple[int, int],
    geometry: Geometry,
    background: tuple[int, int, int],
) -> bool:
    """Check whether a glyph run looks like "-": a short bar near mid-height."""
    pixels = image.load()
    rows = {
        y
        for x in range(run[0], run[1] + 1)
        for y in range(geometry.top, geometry.bottom + 1)
        if is_ink(pixels[x, y], background)
    }
    if not rows or run[1] - run[0] < 1:
        return False
    tall = max(3, geometry.baseline - geometry.top + 1)
    return (
        min(rows) >= geometry.top + tall * 0.3
        and max(rows) <= geometry.baseline - tall * 0.15
        and max(rows) - min(rows) + 1 <= max(2, round(tall * 0.25))
    )


def snap_to_gap(image: Image.Image, x: int, geometry: Geometry, background) -> int:
    """Move a span edge to the nearby column with the least ink."""
    pixels = image.load()
    candidates = range(max(geometry.left, x - 2), min(geometry.right + 1, x + 3))

    def ink_count(column: int) -> int:
        return sum(
            is_ink(pixels[column, y], background)
            for y in range(geometry.top, geometry.bottom + 1)
        )

    return min(candidates, key=lambda column: (ink_count(column), abs(column - x)), default=x)


def render(
    image: Image.Image,
    ink_left: int,
    baseline: int,
    text: str,
    font: ImageFont.FreeTypeFont,
    color: tuple[int, int, int],
    max_width: int,
) -> int:
    """Draw text so its ink starts at ink_left and sits on the baseline row.

    Returns the drawn ink width. Text wider than max_width is compressed
    horizontally to fit.
    """
    left, top, right, bottom = font.getbbox(text, anchor="ls")
    width = max(1, right - left)
    height = max(1, bottom - top)
    layer = Image.new("RGBA", (width + 2, height + 2), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((1 - left, 1 - top), text, font=font, fill=color + (255,), anchor="ls")
    if 0 < max_width < width:
        layer = layer.resize((max_width + 2, layer.height), Image.Resampling.LANCZOS)
        width = max_width
    image.paste(layer, (ink_left - 1, baseline + top), layer)
    return width


def line_extent(
    image: Image.Image,
    geometry: Geometry,
    background: tuple[int, int, int],
    limit: int = 1200,
) -> int:
    """Find where the text run that follows a word ends.

    The run continues to the right while gaps stay smaller than 40 pixels. Its
    end is the last column with ink, so the run can be moved left as one piece.
    """
    pixels = image.load()
    top = max(0, geometry.top - 2)
    bottom = min(image.height - 1, geometry.bottom + 2)
    end = geometry.right
    empty = 0
    for x in range(geometry.right + 1, min(image.width, geometry.right + limit)):
        if any(is_ink(pixels[x, y], background) for y in range(top, bottom + 1)):
            end, empty = x, 0
        else:
            empty += 1
            if empty >= 40:
                break
    return end


def band_is_plain(
    image: Image.Image,
    left: int,
    right: int,
    top: int,
    bottom: int,
    background: tuple[int, int, int],
) -> bool:
    """Check that only the background shows above and below a text band."""
    pixels = image.load()
    for y in (top - 1, bottom + 1):
        if y < 0 or y >= image.height:
            continue
        for x in range(max(0, left), min(image.width, right + 1)):
            if sum(abs(int(pixels[x, y][index]) - background[index]) for index in range(3)) > 30:
                return False
    return True


def merge_replacements(batch: list[Replacement]) -> list[Replacement]:
    """Combine all spans found in one OCR word into one replacement.

    Replacing one span moves the text that follows it. A second span in the
    same word would then use stale positions. So the spans of one word are
    applied to the word's text first, and the word is redrawn once from the
    first changed character to the end of the last changed span.
    """
    groups: dict[tuple[int, int, int, int], list[Replacement]] = {}
    order: list[tuple[int, int, int, int]] = []
    for replacement in batch:
        box = bounds(replacement.words)
        if box not in groups:
            groups[box] = []
            order.append(box)
        groups[box].append(replacement)

    merged: list[Replacement] = []
    for box in order:
        spans = sorted(groups[box], key=lambda item: (item.start, -(item.end - item.start)))
        accepted: list[Replacement] = []
        for span in spans:
            if any(span.start < kept.end and kept.start < span.end for kept in accepted):
                continue
            accepted.append(span)
        if len(accepted) == 1:
            merged.append(accepted[0])
            continue
        original = accepted[0].original
        start = accepted[0].start
        end = accepted[-1].end
        pieces: list[str] = []
        cursor = start
        for span in accepted:
            pieces.append(original[cursor : span.start])
            pieces.append(span.new)
            cursor = span.end
        new_text = "".join(pieces)
        kinds = " + ".join(dict.fromkeys(span.kind for span in accepted))
        merged.append(Replacement(accepted[0].words, original, start, end, new_text, kinds))
    return merged


def replace_span(image: Image.Image, replacement: Replacement) -> None:
    box = bounds(replacement.words)
    background = background_color(image, box)
    geometry = measure(image, box, background)
    if geometry is None:
        # Nothing measurable: clear the OCR box and draw the text inside it.
        ImageDraw.Draw(image).rectangle(box, fill=background)
        if replacement.new:
            font = load_font(
                next(path for path in FONT_CANDIDATES if Path(path).is_file()),
                max(8, box[3] - box[1]),
            )
            render(image, box[0], box[3], replacement.new, font, (90, 90, 90), box[2] - box[0])
        return

    rough = (geometry.left, geometry.top, geometry.right + 1, geometry.bottom + 1)
    color = text_color(image, rough, background)
    drawn_text = as_drawn(replacement.original)
    font = calibrated_font(drawn_text, geometry, image, background, color)
    full = font.getbbox(drawn_text, anchor="ls")
    scale = (geometry.right - geometry.left + 1) / max(1, full[2] - full[0])

    glyph_runs = ink_runs(image, geometry, background)

    def position(index: int) -> int:
        if index <= 0:
            return geometry.left
        if index >= len(replacement.original):
            return geometry.right + 1
        advance = font.getlength(drawn_text[:index]) - full[0]
        estimate = round(geometry.left + advance * scale)
        previous = replacement.original[index - 1]
        cell = max(1, round(scale * font.getlength("m")))
        if index == replacement.end and drawn_text[index : index + 1] == "\u2026":
            # A span that ends at an ellipsis ends after the last glyph that is
            # not a dot. An OCR mistake in the span would move the estimate.
            dots = 0
            for run in reversed(glyph_runs):
                if not is_dot(image, run, geometry, background):
                    break
                dots += 1
            if 0 < dots < len(glyph_runs):
                return glyph_runs[-dots - 1][1] + 1
        if index == replacement.end and replacement.original[index] == "-":
            # OCR mistakes later in the word (an extra or missing letter) move
            # the width estimate. A hyphen right after the span is easy to find
            # from its shape, so end the span after the glyph just before it.
            hyphens = [
                (number, run) for number, run in enumerate(glyph_runs)
                if number > 0
                and is_hyphen(image, run, geometry, background)
                and abs(run[0] - estimate) <= 2 * cell
            ]
            if hyphens:
                number, _ = min(hyphens, key=lambda item: abs(item[1][0] - estimate))
                return glyph_runs[number - 1][1] + 1
        if index == replacement.start and previous == "/":
            # Find the slash from its shape instead of from the width estimate,
            # which can be off by a whole character. A slash is the glyph run
            # whose ink climbs from bottom-left to top-right across the full
            # letter height. Start the span right after that run.
            slashes = [
                run for run in glyph_runs
                if is_slash(image, run, geometry, background)
                and abs(run[1] + 1 - estimate) <= 3 * max(1, round(scale * font.getlength("m")))
            ]
            if slashes:
                best = min(slashes, key=lambda run: abs(run[1] + 1 - estimate))
                return best[1] + 1
        return snap_to_gap(image, estimate, geometry, background)

    span_left = position(replacement.start)
    span_right = position(replacement.end)
    if span_right > span_left + 2:
        color = text_color(
            image, (span_left, geometry.top, span_right, geometry.bottom + 1), background
        )

    band_top = max(0, geometry.top - 3)
    band_bottom = min(image.height - 1, geometry.bottom + 3)

    # Everything after the private span on this text line moves as one piece:
    # the rest of the word, the gap, and the following words. Moving it keeps
    # the original spacing when the new text is shorter or longer.
    run_end = line_extent(image, geometry, background)
    plain = band_is_plain(image, span_left - 4, run_end + 4, band_top, band_bottom, background)
    tail = None
    if plain and span_right <= run_end:
        tail = image.crop((span_right, band_top, run_end + 1, band_bottom + 1))

    new_width = 0
    if replacement.new:
        new_box = font.getbbox(replacement.new, anchor="ls")
        new_width = new_box[2] - new_box[0]

    # Clear one extra column to the left only when the span starts a word. When
    # a separator such as "/" comes right before it, that column can be part of
    # the separator glyph and must stay.
    clear_left = span_left - 1 if replacement.start == 0 else span_left
    clear_left = max(0, clear_left)

    if tail is not None:
        ImageDraw.Draw(image).rectangle(
            (clear_left, band_top, run_end + 1, band_bottom), fill=background
        )
        drawn = 0
        if replacement.new:
            drawn = render(image, span_left, geometry.baseline, replacement.new, font, color, 0)
        # Keep the original distance between the end of the private text and
        # whatever followed it.
        image.paste(tail, (span_left + drawn, band_top))
        return

    # The band is not plain (for example, the text sits on a chip or a
    # highlight). Replace the span in place without moving other content.
    gap = geometry.neighbor_left - geometry.right - 1
    keep_gap = min(gap, max(3, round(gap * 0.6)))
    suffix = None
    if span_right <= geometry.right:
        suffix = image.crop((span_right, band_top, geometry.right + 1, band_bottom + 1))
    suffix_width = suffix.width if suffix else 0
    room = (geometry.neighbor_left - keep_gap) - span_left - suffix_width
    clear_right = min(geometry.neighbor_left - 1, max(geometry.right + 1, span_left + new_width + suffix_width) + 2)
    ImageDraw.Draw(image).rectangle(
        (clear_left, band_top, clear_right, band_bottom), fill=background
    )
    drawn = 0
    if replacement.new:
        drawn = render(image, span_left, geometry.baseline, replacement.new, font, color, max(1, room))
    if suffix is not None:
        image.paste(suffix, (span_left + drawn, band_top))


def local_identity_tokens() -> tuple[list[str], list[str]]:
    """Return the macOS account name and machine names of this computer.

    Terminal prompts and file paths show them, but the app's Accessibility tree
    does not, so they are read from the system instead.
    """
    accounts: list[str] = []
    hosts: list[str] = []
    try:
        import getpass

        accounts.append(getpass.getuser())
    except Exception:
        pass
    for command in (["scutil", "--get", "LocalHostName"], ["hostname", "-s"]):
        try:
            value = subprocess.run(command, check=True, capture_output=True, text=True).stdout.strip()
        except (OSError, subprocess.CalledProcessError):
            continue
        if value and value not in hosts:
            hosts.append(value)
    return accounts, hosts


def fit_truncated(text: str, span: tuple[int, int], new: str) -> str:
    """Shorten a replacement for a label that the app cut with an ellipsis.

    The app shortens a long label to fit its space. If the private text runs
    into that ellipsis, a longer replacement would push the ellipsis into the
    next control. Keep the same number of characters, as the app would.
    """
    rest = text[span[1]:]
    if re.match(r"(?:\.{2,}|\u2026)$", rest) and len(new) > span[1] - span[0]:
        return new[: max(3, span[1] - span[0])]
    return new


def collect_replacements(
    words: list[dict[str, object]],
    display_names: list[str],
    private_tokens: list[str],
    require_names: bool = True,
    include_version: bool = True,
    host_tokens: list[str] | None = None,
) -> list[Replacement]:
    replacements: list[Replacement] = []
    for name in display_names:
        matches = phrase_matches(words, name)
        if not matches and require_names:
            fail(
                f"OCR did not locate visible profile name {name!r}. "
                "Keep the raw capture and review it manually."
            )
        for match in matches:
            original = " ".join(str(word["text"]) for word in match)
            replacements.append(
                Replacement(match, original, 0, len(original), SAFE_DISPLAY_NAME, "profile name")
            )

    for token in private_tokens:
        for word in words:
            text = str(word["text"])
            span = approximate_span(text, token)
            if span is None:
                continue
            replacements.append(
                Replacement([word], text, span[0], span[1], fit_truncated(text, span, SAFE_OWNER), "account handle")
            )

    for host in host_tokens or []:
        for word in words:
            text = str(word["text"])
            span = approximate_span(text, host)
            if span is None:
                continue
            replacements.append(
                Replacement([word], text, span[0], span[1], fit_truncated(text, span, SAFE_HOST), "machine name")
            )

    if include_version and is_settings_screen(words):
        for word in words:
            text = str(word["text"])
            found = VERSION_PATTERN.search(text)
            if found:
                replacements.append(
                    Replacement([word], text, found.start(), found.end(), "", "Settings version")
                )
    return replacements


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
    tokens: list[str] = []
    for value in [
        *identities.get("repositoryOwners", []),
        *identities.get("accountNames", []),
        # The account form of the profile name (for example, "exampleperson")
        # can appear in text that Accessibility does not expose, such as
        # terminal output or file paths. Always treat it as private.
        *(normalize(name) for name in display_names),
    ]:
        cleaned = value.strip(".,:;")
        if (
            cleaned
            and normalize(cleaned) != normalize(SAFE_OWNER)
            and normalize(cleaned) not in {normalize(token) for token in tokens}
        ):
            tokens.append(cleaned)
    local_accounts, hosts = local_identity_tokens()
    for account in local_accounts:
        if (
            len(account) >= 5
            and normalize(account) != normalize(SAFE_OWNER)
            and normalize(account) not in {normalize(token) for token in tokens}
        ):
            tokens.append(account)

    with Image.open(args.input) as source:
        image = opaque(source)
    words = ocr_words(args.input)
    replacements = collect_replacements(words, display_names, tokens, host_tokens=hosts)
    applied: list[str] = []

    def apply(batch: list[Replacement]) -> None:
        for replacement in merge_replacements(batch):
            replace_span(image, replacement)
            applied.append(f"{replacement.kind} -> {replacement.new or '(removed)'}")

    apply(replacements)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)

    # Read the result again with each verification pass. Replace anything a
    # pass still finds, then read again. Fail if private text remains.
    for _ in range(3):
        leftovers: list[Replacement] = []
        for scale, psm in VERIFY_PASSES:
            pass_words = ocr_words(args.output, scale, psm)
            leftovers = collect_replacements(
                pass_words, display_names, tokens,
                require_names=False, include_version=False, host_tokens=hosts,
            )
            if leftovers:
                break
        if not leftovers:
            break
        apply(leftovers)
        image.save(args.output)

    remaining_words: list[dict[str, object]] = []
    for scale, psm in VERIFY_PASSES:
        remaining_words.extend(ocr_words(args.output, scale, psm))
    remaining_text = " ".join(str(word["text"]) for word in remaining_words)
    for name in display_names:
        if phrase_matches(remaining_words, name):
            fail(f"Sanitization verification found identity text {name!r} in the output image.")
    for token in [*tokens, *hosts]:
        if any(approximate_span(str(word["text"]), token) for word in remaining_words):
            fail(f"Sanitization verification found identity text {token!r} in the output image.")
    for source in [*display_names, *tokens]:
        if normalize(source) in normalize(remaining_text):
            fail(f"Sanitization verification found identity text {source!r} in the output image.")
    if is_settings_screen(remaining_words) and VERSION_PATTERN.search(remaining_text):
        fail("Sanitization verification found an app version on the Settings screen.")

    print(f"sanitized={args.output}")
    print(f"replacements={len(applied)}")
    for replacement in applied:
        print(f"  {replacement}")


if __name__ == "__main__":
    main()
