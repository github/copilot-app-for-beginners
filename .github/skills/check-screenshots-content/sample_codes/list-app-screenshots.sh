#!/usr/bin/env bash
# list-app-screenshots.sh
#
# Discover app screenshots (files named "app-*" inside any assets/ folder) and
# convert each to a PNG the agent's image view tool can load reliably. Some
# .webp captures fail to load directly, so a PNG copy is written to a temp dir.
#
# Usage:
#   bash list-app-screenshots.sh [OUTPUT_DIR]
#
# Output: a two-column list of "SOURCE  VIEWABLE_PNG" the agent can view and
# cross-check against chapter README content.

set -euo pipefail

# Repo root is four levels up from this script's sample_codes/ folder.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

OUT_DIR="${1:-/tmp/screenshot-check}"
mkdir -p "$OUT_DIR"

found=0
printf '%-64s  %s\n' "SOURCE" "VIEWABLE_PNG"

# Portable across macOS bash 3.2 (no mapfile). Filenames are not expected to
# contain newlines.
while IFS= read -r src; do
  [ -n "$src" ] || continue
  found=1
  base="$(basename "$src")"
  stem="${base%.*}"
  ext="${base##*.}"
  if [ "$ext" = "png" ]; then
    viewable="$src"
  else
    viewable="$OUT_DIR/$stem.png"
    if ! sips -s format png "$src" --out "$viewable" >/dev/null 2>&1; then
      echo "WARN: could not convert $src" >&2
      continue
    fi
  fi
  printf '%-64s  %s\n' "$src" "$viewable"
done < <(find . -type f -path '*/assets/app-*' \
  \( -name '*.webp' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
  | sort)

if [ "$found" -eq 0 ]; then
  echo "No app-* screenshots found under */assets/." >&2
  echo "Convention: name app screenshots 'app-<topic>.webp' and place them in <chapter>/assets/." >&2
fi
