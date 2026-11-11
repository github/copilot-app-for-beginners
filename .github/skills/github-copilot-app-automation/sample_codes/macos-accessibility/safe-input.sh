#!/usr/bin/env bash
#
# Guard for real (system-wide) input: pointer moves, AppleScript keystrokes, and
# shortcuts. Run it right before such input, so the automation never fights a
# person at the keyboard or types into another app.
#
#   safe-input.sh idle  [seconds=3] [timeout=120]   wait until nobody has used the
#                                                   keyboard or mouse for <seconds>
#   safe-input.sh front <pid>                       exit 1 unless <pid> is the
#                                                   frontmost app
#
# "front" uses app-demo-automation's `act front` when that sibling user-level
# skill is installed and built (the same check its video takes use), and
# System Events otherwise. COPILOT_INPUT_IDLE sets the idle seconds that the
# persona scripts wait for (0 turns the wait off).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
skills="$(cd "$here/../../.." && pwd)"
act="${DEMO_ACT:-$skills/app-demo-automation/scripts/act}"

idle_seconds() {
  ioreg -c IOHIDSystem | awk '/HIDIdleTime/ { print int($NF / 1000000000); exit }'
}

case "${1:-}" in
  idle)
    need="${2:-3}"
    timeout="${3:-120}"
    [ "$need" -gt 0 ] 2>/dev/null || exit 0
    deadline=$(( $(date +%s) + timeout ))
    while [ "$(idle_seconds)" -lt "$need" ]; do
      if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "safe-input: a person kept using the computer for ${timeout}s; not sending input." >&2
        exit 2
      fi
      sleep 1
    done
    ;;
  front)
    pid="${2:?pid required}"
    if [ -x "$act" ]; then
      front="$("$act" front 2>/dev/null | awk '{ print $1 }')"
    else
      front="$(osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' 2>/dev/null || true)"
    fi
    if [ "$front" != "$pid" ]; then
      echo "safe-input: the frontmost app is ${front:-unknown}, not $pid; not sending input." >&2
      exit 1
    fi
    ;;
  *)
    sed -n '3,14p' "$0" >&2
    exit 64
    ;;
esac
