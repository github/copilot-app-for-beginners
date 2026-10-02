#!/usr/bin/env bash
#
# Replace the visible profile name with "Copilot Dev" and matching account
# handles or repository owners with "copilotdev". Avatars and unrelated owners
# remain.
#
# The identities come from the app's Accessibility tree. While a dialog is open,
# the app hides the sidebar (and its profile control) from Accessibility, even
# though the sidebar is still visible in the screenshot. So the identities are
# cached per process the first time they are found, and later captures of the
# same process reuse the cache. prepare-persona.sh fills the cache before any
# dialog can be open. If no profile name is known, the capture fails instead of
# saving an image that could show a real name.
#
# Usage:
#   sanitize-screenshot.sh <process_id> <input_png> <output_png>
set -euo pipefail

target_pid="${1:?process_id required}"
input_png="${2:?input_png required}"
output_png="${3:?output_png required}"

[[ "$target_pid" =~ ^[0-9]+$ ]] || {
  echo "Process ID must be numeric: $target_pid" >&2
  exit 1
}
[ -f "$input_png" ] || {
  echo "Input image was not found: $input_png" >&2
  exit 1
}
for tool in swiftc python3 tesseract; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing required privacy tool: $tool" >&2
    exit 1
  }
done

here="$(cd "$(dirname "$0")" && pwd)"
identity_source="$here/find-private-identities.swift"
sanitizer="$here/sanitize-screenshot.py"
[ -f "$identity_source" ] || { echo "Missing $identity_source" >&2; exit 1; }
[ -f "$sanitizer" ] || { echo "Missing $sanitizer" >&2; exit 1; }

identity_finder="$(mktemp -t find-private-identities)"
identities="$(mktemp -t copilot-identities).json"
trap 'rm -f "$identity_finder" "$identities"' EXIT

swiftc "$identity_source" -o "$identity_finder" 2>/dev/null || {
  echo "swiftc failed to build the identity finder." >&2
  exit 1
}
"$identity_finder" "$target_pid" >"$identities"

cache_dir="${TMPDIR:-/tmp}/copilot-capture-identities"
cache="$cache_dir/$target_pid.json"
has_names() {
  python3 -c 'import json,sys; raise SystemExit(not json.load(open(sys.argv[1])).get("displayNames"))' "$1"
}
if has_names "$identities"; then
  mkdir -p "$cache_dir"
  chmod 700 "$cache_dir"
  cp "$identities" "$cache"
  chmod 600 "$cache"
elif [ -f "$cache" ] && has_names "$cache"; then
  # A dialog hides the sidebar from Accessibility. Use the cached identities.
  cp "$cache" "$identities"
else
  echo "No profile name was found for process $target_pid, and no cached identities exist." >&2
  echo "Close any open dialog and capture once, or rerun prepare-persona.sh." >&2
  exit 6
fi

python3 "$sanitizer" "$input_png" "$output_png" "$identities"
