#!/usr/bin/env bash
#
# Stop one screenshot process and preserve its signed-in persona home.
#
# Usage:
#   cleanup-persona.sh <persona> <process_id>
set -euo pipefail

persona="${1:?persona required}"
target_pid="${2:?process_id required}"

[[ "$persona" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "Persona must contain only letters, numbers, dots, underscores, or hyphens." >&2
  exit 1
}
[[ "$target_pid" =~ ^[0-9]+$ ]] || {
  echo "Process ID must be numeric: $target_pid" >&2
  exit 1
}

if ps -p "$target_pid" -o command= 2>/dev/null | grep -q '^/Applications/GitHub Copilot.app/Contents/MacOS/github'; then
  kill "$target_pid"
  for _ in {1..20}; do
    ps -p "$target_pid" >/dev/null 2>&1 || break
    sleep 0.25
  done
fi

echo "closed_process=$target_pid"
echo "preserved_persona=$persona"
