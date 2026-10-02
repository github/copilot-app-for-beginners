#!/usr/bin/env bash
#
# Launch a separate GitHub Copilot app instance with an isolated HOME, then
# give only that instance the 16:9 capture frame (1920x1080 points by default).
#
# On a standard-resolution display, the 1920x1080-point frame captures as a
# native 1080p image. The script then resets the web zoom and zooms in exactly
# twice (125%), as the skill requires, and confirms the zoom.
#
# COPILOT_CAPTURE_WIDTH and COPILOT_CAPTURE_ZOOM_STEPS (0-7) exist only for
# special cases. Course screenshots use the defaults.
#
# A standard window is used instead of full screen because full screen can
# draw the menu bar and title bar over the app content while the app is active.
#
# Usage:
#   launch-persona.sh [persona] [timeout_seconds]
#
# The new app process ID is the only value written to stdout. Pass it to
# capture-window.sh so capture never selects another Copilot app instance.
set -euo pipefail

persona="${1:-demo}"
timeout="${2:-45}"
app_name="GitHub Copilot"
app_executable="/Applications/GitHub Copilot.app/Contents/MacOS/github"

[[ "$persona" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "Persona must contain only letters, numbers, dots, underscores, or hyphens." >&2
  exit 1
}
[[ "$timeout" =~ ^[0-9]+$ ]] && [ "$timeout" -gt 0 ] || {
  echo "Timeout must be a positive integer." >&2
  exit 1
}
[ -x "$app_executable" ] || {
  echo "GitHub Copilot app was not found at $app_executable" >&2
  exit 1
}
here="$(cd "$(dirname "$0")" && pwd)"
window_control_src="$here/control-copilot-window.swift"
[ -f "$window_control_src" ] || {
  echo "Missing $window_control_src" >&2
  exit 1
}
for tool in open pgrep python3 swiftc; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing required tool: $tool" >&2
    exit 1
  }
done

user_home="$(python3 -c 'import os, pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')"
personas_root="${COPILOT_PERSONAS_ROOT:-$user_home/CopilotPersonas}"
persona_home="$personas_root/$persona"
mkdir -p "$persona_home"

before="$(mktemp -t copilot-persona-pids)"
trap 'rm -f "$before"' EXIT
pgrep -f "^${app_executable}( |$)" 2>/dev/null | sort -n >"$before" || true

echo "Launching GitHub Copilot persona '$persona'..." >&2
open -na "$app_name" --env HOME="$persona_home"

deadline=$(( $(date +%s) + timeout ))
pid=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  while IFS= read -r candidate; do
    if ! grep -qx "$candidate" "$before"; then
      pid="$candidate"
      break
    fi
  done < <(pgrep -f "^${app_executable}( |$)" 2>/dev/null | sort -n || true)
  [ -n "$pid" ] && break
  sleep 1
done

[ -n "$pid" ] || {
  echo "A new GitHub Copilot process did not appear within ${timeout}s." >&2
  exit 2
}

capture_width="${COPILOT_CAPTURE_WIDTH:-1920}"
[[ "$capture_width" =~ ^[0-9]+$ ]] || {
  echo "COPILOT_CAPTURE_WIDTH must be a whole number of points." >&2
  exit 1
}
echo "Waiting for process $pid, applying the ${capture_width}-point 16:9 capture frame and capture zoom..." >&2
window_control="$(mktemp -t control-copilot-window)"
trap 'rm -f "$before" "$window_control"' EXIT
swiftc "$window_control_src" -o "$window_control" 2>/dev/null || {
  echo "swiftc failed to build the window controller." >&2
  exit 3
}
"$window_control" "$pid" frame "$timeout" "$capture_width" >/dev/null
if [ -n "${COPILOT_CAPTURE_ZOOM_STEPS:-}" ]; then
  "$window_control" "$pid" capture-zoom "$timeout" "$COPILOT_CAPTURE_ZOOM_STEPS" >/dev/null
else
  "$window_control" "$pid" capture-zoom "$timeout" >/dev/null
fi

printf '%s\n' "$pid"
