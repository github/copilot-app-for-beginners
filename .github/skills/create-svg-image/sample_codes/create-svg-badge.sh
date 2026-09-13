#!/usr/bin/env bash
# create-svg-badge.sh
#
# Wrap a raster image (.webp/.png/.jpg) in an SVG and overlay a numbered red
# "step" badge (a filled circle with a white number) at a chosen position.
#
# Why an SVG that embeds the image as base64?
#   GitHub renders an SVG referenced from Markdown (![](file.svg)) inside a
#   sandboxed <img>. In that mode GitHub (1) strips inline <svg> from READMEs and
#   (2) refuses to fetch an external/relative <image href="photo.webp">. Encoding
#   the raster as a data: URI inside the SVG is what makes the photo show up on a
#   GitHub README. The badge stays editable as plain SVG markup.
#
# Required inputs:
#   --image PATH     Source raster image to badge (.webp, .png, .jpg/.jpeg).
#   --x N            Circle center X, in the image's native pixel coordinates.
#   --y N            Circle center Y, in the image's native pixel coordinates.
#   --number N       Number (or short text) to render inside the circle.
#
# Optional:
#   --out PATH       Output .svg path (default: <image-dir>/<stem>-step<number>.svg).
#   --radius N       Circle radius in px. Default scales to ~2.5% of the image
#                    width so badges look the same size across screenshots
#                    (e.g. 24px @936px wide, 56px @2240px wide).
#   --color HEX      Circle fill color (default: #d1242f, GitHub danger red).
#   --text-color HEX Number color (default: #ffffff).
#   --width N        Override image width if auto-detection fails.
#   --height N       Override image height if auto-detection fails.
#   --grid           Don't write the final file. Instead render a coordinate-grid
#                    preview so you can read off the right --x/--y, then re-run
#                    without --grid. (Preview only; nothing is written to the repo.)
#   --no-preview     Skip rendering the verification PNG preview.
#
# Output:
#   Prints the path to the written SVG and, when a renderer is available, the path
#   to a PNG preview (in a temp dir) you can open/view to verify placement.
#
# Usage examples:
#   # 1) Find coordinates first (preview only, writes nothing to the repo):
#   bash create-svg-badge.sh --image chap/assets/app-foo.webp --x 0 --y 0 --number 1 --grid
#
#   # 2) Generate the badged SVG once you know where the circle goes:
#   bash create-svg-badge.sh --image chap/assets/app-foo.webp --x 710 --y 72 --number 1
#
#   # 3) Then reference the .svg (not the raster) from the chapter README:
#   #    ![Alt text](assets/app-foo-step1.svg)

set -euo pipefail

IMAGE=""
X=""
Y=""
NUMBER=""
OUT=""
RADIUS=""
COLOR="#d1242f"
TEXT_COLOR="#ffffff"
WIDTH=""
HEIGHT=""
GRID=0
PREVIEW=1

die() { echo "ERROR: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --image)      IMAGE="${2:-}"; shift 2 ;;
    --x)          X="${2:-}"; shift 2 ;;
    --y)          Y="${2:-}"; shift 2 ;;
    --number)     NUMBER="${2:-}"; shift 2 ;;
    --out)        OUT="${2:-}"; shift 2 ;;
    --radius)     RADIUS="${2:-}"; shift 2 ;;
    --color)      COLOR="${2:-}"; shift 2 ;;
    --text-color) TEXT_COLOR="${2:-}"; shift 2 ;;
    --width)      WIDTH="${2:-}"; shift 2 ;;
    --height)     HEIGHT="${2:-}"; shift 2 ;;
    --grid)       GRID=1; shift ;;
    --no-preview) PREVIEW=0; shift ;;
    -h|--help)    sed -n '2,40p' "$0"; exit 0 ;;
    *)            die "Unknown argument: $1" ;;
  esac
done

# --- Validate required inputs ------------------------------------------------
[ -n "$IMAGE" ]  || die "--image is required"
[ -f "$IMAGE" ]  || die "image not found: $IMAGE"
[ -n "$NUMBER" ] || die "--number is required"
if [ "$GRID" -eq 0 ]; then
  [ -n "$X" ] || die "--x is required (use --grid first if you don't know it)"
  [ -n "$Y" ] || die "--y is required (use --grid first if you don't know it)"
fi

# --- Detect mime type from extension ----------------------------------------
ext="${IMAGE##*.}"
case "$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')" in
  webp)      MIME="image/webp" ;;
  png)       MIME="image/png" ;;
  jpg|jpeg)  MIME="image/jpeg" ;;
  *)         die "unsupported image type: .$ext (use webp, png, or jpg)" ;;
esac

# --- Detect image dimensions -------------------------------------------------
if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
  if command -v sips >/dev/null 2>&1; then
    WIDTH="${WIDTH:-$(sips -g pixelWidth "$IMAGE" 2>/dev/null | awk '/pixelWidth/{print $2}')}"
    HEIGHT="${HEIGHT:-$(sips -g pixelHeight "$IMAGE" 2>/dev/null | awk '/pixelHeight/{print $2}')}"
  fi
  if [ -z "$WIDTH" ] && command -v identify >/dev/null 2>&1; then
    dims="$(identify -format '%w %h' "$IMAGE" 2>/dev/null || true)"
    WIDTH="${dims%% *}"; HEIGHT="${dims##* }"
  fi
fi
[ -n "$WIDTH" ] && [ -n "$HEIGHT" ] || \
  die "could not detect image size; pass --width and --height explicitly"

# --- Default radius scales with image width ----------------------------------
# Badges should render at a consistent on-screen size no matter the screenshot
# resolution. README images are scaled to the column width, so anchoring the
# radius to 2.5% of the image width keeps every badge visually the same diameter
# (e.g. 24px on a 936px-wide capture, 56px on a 2240px-wide capture). Override
# with --radius for a one-off.
if [ -z "$RADIUS" ]; then
  RADIUS="$(awk "BEGIN{r=$WIDTH*0.025; if(r<12)r=12; printf \"%d\", r+0.5}")"
fi

# --- Derived badge geometry --------------------------------------------------
FONT_SIZE="$(awk "BEGIN{printf \"%d\", $RADIUS*1.25}")"
STROKE="$(awk "BEGIN{s=$RADIUS/8; if(s<2)s=2; printf \"%d\", s}")"

# --- Base64-encode the raster (no line wraps) --------------------------------
B64="$(base64 < "$IMAGE" | tr -d '\n')"

TMPDIR_OUT="${TMPDIR:-/tmp}/create-svg-badge"
mkdir -p "$TMPDIR_OUT"

render_preview() {
  # $1 = svg path, $2 = png out path
  if command -v qlmanage >/dev/null 2>&1; then
    qlmanage -t -s "$WIDTH" -o "$TMPDIR_OUT" "$1" >/dev/null 2>&1 || return 1
    mv "$TMPDIR_OUT/$(basename "$1").png" "$2" 2>/dev/null || return 1
    return 0
  elif command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert "$1" -o "$2" >/dev/null 2>&1 || return 1
    return 0
  fi
  return 2
}

# --- Grid mode: preview coordinates, write nothing to the repo ---------------
if [ "$GRID" -eq 1 ]; then
  grid_svg="$TMPDIR_OUT/grid.svg"
  {
    printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s %s" width="%s" height="%s">\n' "$WIDTH" "$HEIGHT" "$WIDTH" "$HEIGHT"
    printf '  <image x="0" y="0" width="%s" height="%s" href="data:%s;base64,%s"/>\n' "$WIDTH" "$HEIGHT" "$MIME" "$B64"
    step="$(awk "BEGIN{printf \"%d\", ($WIDTH/10 < 40 ? 40 : $WIDTH/10)}")"
    x=0
    while [ "$x" -le "$WIDTH" ]; do
      printf '  <line x1="%s" y1="0" x2="%s" y2="%s" stroke="#00ff88" stroke-width="1" opacity="0.6"/>\n' "$x" "$x" "$HEIGHT"
      printf '  <text x="%s" y="14" fill="#00ff88" font-size="12" text-anchor="middle">%s</text>\n' "$x" "$x"
      x=$((x + step))
    done
    y=0
    while [ "$y" -le "$HEIGHT" ]; do
      printf '  <line x1="0" y1="%s" x2="%s" y2="%s" stroke="#ff00ff" stroke-width="1" opacity="0.6"/>\n' "$y" "$WIDTH" "$y"
      printf '  <text x="4" y="%s" fill="#ff00ff" font-size="12">%s</text>\n' "$((y + 12))" "$y"
      y=$((y + step))
    done
    printf '</svg>\n'
  } > "$grid_svg"
  grid_png="$TMPDIR_OUT/grid.png"
  if render_preview "$grid_svg" "$grid_png"; then
    echo "GRID_PREVIEW: $grid_png"
    echo "Read the green (X) and magenta (Y) labels, then re-run with --x and --y."
  else
    echo "GRID_SVG: $grid_svg (no renderer found; open it to read coordinates)"
  fi
  exit 0
fi

# --- Generate the final badged SVG -------------------------------------------
if [ -z "$OUT" ]; then
  dir="$(dirname "$IMAGE")"
  base="$(basename "$IMAGE")"
  stem="${base%.*}"
  OUT="$dir/$stem-step$NUMBER.svg"
fi

{
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s %s" width="%s" height="%s" role="img" aria-label="Step %s">\n' "$WIDTH" "$HEIGHT" "$WIDTH" "$HEIGHT" "$NUMBER"
  printf '  <image x="0" y="0" width="%s" height="%s" href="data:%s;base64,%s"/>\n' "$WIDTH" "$HEIGHT" "$MIME" "$B64"
  printf '  <circle cx="%s" cy="%s" r="%s" fill="%s" stroke="#ffffff" stroke-width="%s"/>\n' "$X" "$Y" "$RADIUS" "$COLOR" "$STROKE"
  printf '  <text x="%s" y="%s" font-family="Helvetica, Arial, sans-serif" font-size="%s" font-weight="700" fill="%s" text-anchor="middle" dominant-baseline="central">%s</text>\n' "$X" "$Y" "$FONT_SIZE" "$TEXT_COLOR" "$NUMBER"
  printf '</svg>\n'
} > "$OUT"

# --- Validate well-formedness ------------------------------------------------
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$OUT" || die "generated SVG is not well-formed XML: $OUT"
fi

echo "SVG: $OUT"

# --- Optional verification preview -------------------------------------------
if [ "$PREVIEW" -eq 1 ]; then
  preview="$TMPDIR_OUT/$(basename "${OUT%.*}").png"
  if render_preview "$OUT" "$preview"; then
    echo "PREVIEW: $preview"
    echo "View the preview to confirm placement. Note: macOS qlmanage pads the"
    echo "preview to a square; only the top ${HEIGHT}px strip is the real image."
  else
    echo "PREVIEW: (no SVG renderer found; install librsvg or use macOS qlmanage)"
  fi
fi
