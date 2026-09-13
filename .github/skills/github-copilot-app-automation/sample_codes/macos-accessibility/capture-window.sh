#!/usr/bin/env bash
#
# Capture the visible GitHub Copilot app window by its CoreGraphics window id.
# Output PNG and WebP files are always normalized to 1920x1080 with a 2px
# #cccccc inside border. Settings screenshots have the displayed app version
# removed. Optional ordered callouts are added after finalization.
#
# Why this exists: the app is WebKit-backed, and `System Events` sometimes
# reports `count of windows = 0` even when a window is visible, which breaks the
# Accessibility-rectangle approach in capture-copilot-window.sh. Capturing by
# CoreGraphics window id is more reliable and also lets us poll for the window
# to appear, which solves the "tell me when ready" problem.
#
# CONSTRAINTS:
#   - The Copilot window must be on the SAME macOS Space as the process running
#     this script. CoreGraphics + `screencapture` only see the active Space; a
#     window on another desktop/Space is invisible to capture. Drag the app onto
#     this desktop first.
#   - The caller needs macOS Screen Recording permission (separate from
#     Accessibility). A denied capture comes back blank/near-solid-color.
#   - Requires: swift (Command Line Tools), screencapture, and a WebP encoder
#     (cwebp preferred, then magick, then ffmpeg).
#
# PRIVACY: this captures real window content (project names, prompts, diffs,
# tokens can appear). Capture from a SANITIZED training account on the training
# fork, and review every image before committing it to course assets.
#
# Usage:
#   capture-window.sh <output_dir> <base_name> [timeout_seconds] [process_id]
#     [--callout NUMBER:X:Y ...]
#
# Example:
#   pid="$(launch-persona.sh demo 45)"
#   capture-window.sh 04-skills-custom-agents/assets app-settings-skills 40 "$pid"
#   capture-window.sh 00-setup/assets app-add-project 40 "$pid" \
#     --callout 1:472:324 --callout 2:743:501
set -euo pipefail

out_dir="${1:?output_dir required}"
base="${2:?base_name required}"
timeout="${3:-30}"
target_pid="${4:-${COPILOT_PID:-}}"
callout_args=()
if [ "$#" -gt 4 ]; then
  callout_args=("${@:5}")
fi
quality="${WEBP_QUALITY:-82}"
target_width=1920
target_height=1080

if [ -n "$target_pid" ] && ! [[ "$target_pid" =~ ^[0-9]+$ ]]; then
  echo "Process ID must be numeric: $target_pid" >&2
  exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"
swift_src="$here/find-copilot-window.swift"
window_control_src="$here/control-copilot-window.swift"
finalizer="$here/finalize-screenshot.py"
callout_tool="$here/add-step-callouts.py"
[ -f "$swift_src" ] || { echo "Missing $swift_src" >&2; exit 1; }
[ -f "$window_control_src" ] || { echo "Missing $window_control_src" >&2; exit 1; }
[ -f "$finalizer" ] || { echo "Missing $finalizer" >&2; exit 1; }
[ -f "$callout_tool" ] || { echo "Missing $callout_tool" >&2; exit 1; }
for tool in swift swiftc screencapture python3 tesseract; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 1; }
done
mkdir -p "$out_dir"
lister="$(mktemp -t findcopilot)"
window_control="$(mktemp -t control-copilot-window)"
identities=""
trap 'rm -f "$lister" "$window_control"; [ -z "$identities" ] || rm -f "$identities"' EXIT
swiftc "$swift_src" -o "$lister" 2>/dev/null || { echo "swiftc failed to build the window lister" >&2; exit 1; }
swiftc "$window_control_src" -o "$window_control" 2>/dev/null || { echo "swiftc failed to build the window controller" >&2; exit 1; }

if [ -n "$target_pid" ]; then
  "$window_control" "$target_pid" activate "$timeout" >/dev/null
fi

pick_window() {
  "$lister" | python3 -c '
import sys
target_pid = sys.argv[1]
best=None; area=0
for ln in sys.stdin:
    d=dict(p.split("=",1) for p in ln.strip().split("|") if "=" in p)
    try:
        if int(d.get("layer","9"))!=0: continue
        if target_pid and d.get("pid") != target_pid: continue
        a=int(d["w"])*int(d["h"])
        if a>area and int(d["h"])>120: area=a; best=d["id"]
    except Exception: pass
print(best or "")
' "$target_pid"
}

if [ -n "$target_pid" ]; then
  echo "Polling up to ${timeout}s for Copilot process $target_pid on the active Space..." >&2
else
  echo "Polling up to ${timeout}s for the largest Copilot window on the active Space..." >&2
  echo "Warning: pass a process ID when more than one Copilot instance can be open." >&2
fi
deadline=$(( $(date +%s) + timeout ))
winid=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  winid="$(pick_window)"
  [ -n "$winid" ] && break
  sleep 2
done
[ -n "$winid" ] || {
  if [ -n "$target_pid" ]; then
    echo "No window for Copilot process $target_pid was found on the active Space within ${timeout}s." >&2
  else
    echo "No Copilot window was found on the active Space within ${timeout}s." >&2
  fi
  echo "Activate the target Copilot window on this desktop/Space and retry." >&2
  exit 2
}

png="$out_dir/$base.png"
webp="$out_dir/$base.webp"
raw_png="$out_dir/$base.raw.png"

screencapture -x -l "$winid" "$raw_png"
[ -s "$raw_png" ] || { echo "Capture produced no file. Grant Screen Recording permission to the caller." >&2; exit 3; }

verdict="$(python3 - "$raw_png" <<'PY'
import sys
from PIL import Image, ImageStat
s = ImageStat.Stat(Image.open(sys.argv[1]).convert("L"))
m, sd = s.mean[0], s.stddev[0]
print(f"mean={m:.1f} stddev={sd:.1f} verdict={'BLANK-or-Screen-Recording-denied' if sd < 3 else 'REAL-content'}")
PY
)"

if [ -n "$target_pid" ]; then
  sanitizer="$here/sanitize-screenshot.sh"
  [ -x "$sanitizer" ] || {
    echo "Missing executable sanitizer: $sanitizer" >&2
    exit 4
  }
  "$sanitizer" "$target_pid" "$raw_png" "$png"
else
  identities="$(mktemp -t copilot-empty-identities).json"
  printf '%s\n' '{"displayNames":[],"repositoryOwners":[],"accountNames":[]}' >"$identities"
  python3 "$here/sanitize-screenshot.py" "$raw_png" "$png" "$identities"
  rm -f "$identities"
fi
rm -f "$raw_png"

python3 "$finalizer" "$png"
if [ "${#callout_args[@]}" -gt 0 ]; then
  python3 "$callout_tool" "$png" "${callout_args[@]}"
fi

if command -v cwebp >/dev/null 2>&1; then
  cwebp -quiet -lossless -q "$quality" -m 6 -metadata none "$png" -o "$webp"
elif command -v magick >/dev/null 2>&1; then
  magick "$png" -strip -define webp:lossless=true -quality "$quality" "$webp"
elif command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -hide_banner -loglevel error -y -i "$png" \
    -c:v libwebp -lossless 1 -compression_level 6 -q:v "$quality" "$webp"
else
  echo "No WebP encoder found. Install cwebp, ImageMagick, or ffmpeg." >&2
  exit 4
fi

python3 - "$png" "$webp" "$target_width" "$target_height" <<'PY'
import sys
from PIL import Image

expected = (int(sys.argv[3]), int(sys.argv[4]))
border_color = (204, 204, 204)
border_width = 2
for path in sys.argv[1:3]:
    with Image.open(path) as image:
        if image.size != expected:
            raise SystemExit(f"{path} is {image.width}x{image.height}; expected 1920x1080.")
        pixels = image.convert("RGB")
        for offset in range(border_width):
            horizontal = [
                pixels.getpixel((x, offset))
                for x in range(expected[0])
            ] + [
                pixels.getpixel((x, expected[1] - 1 - offset))
                for x in range(expected[0])
            ]
            vertical = [
                pixels.getpixel((offset, y))
                for y in range(expected[1])
            ] + [
                pixels.getpixel((expected[0] - 1 - offset, y))
                for y in range(expected[1])
            ]
            if any(pixel != border_color for pixel in horizontal + vertical):
                raise SystemExit(f"{path} does not have an exact 2px #cccccc border.")
PY

echo "png=$png ($(wc -c <"$png") bytes)"
echo "webp=$webp ($(wc -c <"$webp") bytes) quality=$quality"
echo "$verdict"
echo "REVIEW for other private data (prompts, diffs, tokens) before committing to course assets."
