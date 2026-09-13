#!/usr/bin/env bash
#
# Replace the visible profile name with "Copilot Dev" and matching account
# handles or repository owners with "copilotdev". Avatars and unrelated owners
# remain.
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
python3 "$sanitizer" "$input_png" "$output_png" "$identities"
