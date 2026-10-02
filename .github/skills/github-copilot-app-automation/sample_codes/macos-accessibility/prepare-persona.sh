#!/usr/bin/env bash
#
# Launch a new process, enforce public-safe capture settings, and verify one repo.
#
# Usage:
#   prepare-persona.sh <persona> <repository_path> [timeout_seconds]
set -euo pipefail

persona="${1:?persona required}"
repository_path="${2:?repository_path required}"
timeout="${3:-60}"

[[ "$persona" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "Persona must contain only letters, numbers, dots, underscores, or hyphens." >&2
  exit 1
}
[[ "$timeout" =~ ^[0-9]+$ ]] && [ "$timeout" -gt 0 ] || {
  echo "Timeout must be a positive integer." >&2
  exit 1
}

here="$(cd "$(dirname "$0")" && pwd)"
repository_path="$(cd "$repository_path" && pwd -P)"
[ -d "$repository_path/.git" ] || {
  echo "Repository path is not a Git repository: $repository_path" >&2
  exit 1
}

user_home="$(python3 -c 'import os, pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')"
personas_root="${COPILOT_PERSONAS_ROOT:-$user_home/CopilotPersonas}"
persona_home="$personas_root/$persona"
[ -d "$persona_home" ] || {
  echo "Persona is not initialized: $persona_home" >&2
  echo "Create it once and complete GitHub sign-in before automated capture." >&2
  exit 1
}

setup_source="$here/setup-copilot-persona.swift"
control_source="$here/control-copilot-ui.swift"
identity_source="$here/find-private-identities.swift"
streamer_source="$here/ensure-streamer-mode.swift"
state_source="$here/prepare-copilot-state.swift"
[ -f "$setup_source" ] || {
  echo "Missing $setup_source" >&2
  exit 1
}
[ -f "$control_source" ] || { echo "Missing $control_source" >&2; exit 1; }
[ -f "$identity_source" ] || { echo "Missing $identity_source" >&2; exit 1; }
[ -f "$streamer_source" ] || { echo "Missing $streamer_source" >&2; exit 1; }
[ -f "$state_source" ] || { echo "Missing $state_source" >&2; exit 1; }

# In built-in display mode, give focus back to the app that you used before.
front_pid=""
if [ "${COPILOT_CAPTURE_DISPLAY:-}" = "builtin" ]; then
  front_pid="$(osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' 2>/dev/null || true)"
fi

pid="$(bash "$here/launch-persona.sh" "$persona" "$timeout")"
setup_binary="$(mktemp -t setup-copilot-persona)"
control_binary="$(mktemp -t control-copilot-ui)"
identity_binary="$(mktemp -t find-private-identities)"
streamer_binary="$(mktemp -t ensure-streamer-mode)"
state_binary="$(mktemp -t prepare-copilot-state)"
trap 'rm -f "$setup_binary" "$control_binary" "$identity_binary" "$streamer_binary" "$state_binary"' EXIT
swiftc "$control_source" -o "$control_binary" 2>/dev/null || {
  echo "swiftc failed to build the UI control tool." >&2
  exit 2
}
swiftc "$identity_source" -o "$identity_binary" 2>/dev/null || {
  echo "swiftc failed to build the identity finder." >&2
  exit 2
}
swiftc "$setup_source" -o "$setup_binary" 2>/dev/null || {
  echo "swiftc failed to build the persona setup tool." >&2
  exit 2
}
swiftc "$streamer_source" -o "$streamer_binary" 2>/dev/null || {
  echo "swiftc failed to build the Streamer Mode tool." >&2
  exit 2
}
swiftc "$state_source" -o "$state_binary" 2>/dev/null || {
  echo "swiftc failed to build the UI state tool." >&2
  exit 2
}

identities="$("$identity_binary" "$pid")"
if ! python3 -c 'import json,sys; raise SystemExit(not json.load(sys.stdin)["displayNames"])' <<<"$identities"; then
  echo "Persona '$persona' is not signed in. Process $pid was kept for inspection." >&2
  exit 3
fi
# Cache the identities for this process. Captures taken while a dialog is open
# cannot read the profile control, so sanitize-screenshot.sh uses this cache.
cache_dir="${TMPDIR:-/tmp}/copilot-capture-identities"
mkdir -p "$cache_dir"
chmod 700 "$cache_dir"
printf '%s\n' "$identities" >"$cache_dir/$pid.json"
chmod 600 "$cache_dir/$pid.json"

if ! "$streamer_binary" "$pid" "$timeout" >/dev/null; then
  echo "Streamer Mode could not be enabled and verified. Process $pid was kept for inspection." >&2
  exit 4
fi

repository_name="$(basename "$repository_path")"
if ! "$control_binary" "$pid" exists "$repository_name" AXButton >/dev/null 2>&1; then
  if ! "$setup_binary" "$pid" "$repository_path" "$timeout" >/dev/null; then
    echo "Repository setup failed for process $pid. The persona was kept for inspection." >&2
    exit 5
  fi
fi

if ! "$control_binary" "$pid" exists "$repository_name" AXButton >/dev/null 2>&1; then
  echo "Repository verification failed for process $pid: $repository_name" >&2
  exit 6
fi

"$control_binary" "$pid" press New AXButton >/dev/null
# Remove promotions and update notices, then move the pointer off the content
# so no hover state or tooltip appears in the first capture.
"$state_binary" "$pid" dismiss-banners >/dev/null || true
"$state_binary" "$pid" park >/dev/null || true
if [ -n "$front_pid" ] && [ "$front_pid" != "$pid" ]; then
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $front_pid) to true" >/dev/null 2>&1 || true
fi
printf '%s\n' "$pid"
