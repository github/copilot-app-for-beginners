#!/usr/bin/env bash
#
# Read-only factual map of the GitHub Copilot app UI.
#
# Run this BEFORE capturing screenshots so course steps are grounded in the
# app's ACTUAL UI (menus, windows, named controls), and re-run it after an app
# update to see exactly what changed. This is the "base everything on facts"
# and "handle future updates" step.
#
# What it reads (read-only, no clicks, no submits):
#   - App version (from Info.plist)
#   - Full menu bar structure (always readable)
#   - The front window's accessibility tree of NAMED controls (capped)
#
# CONSTRAINT: the deep window/control map requires the app window to be visible
# on the CURRENT macOS Space (same constraint as screenshot capture). Menus are
# always readable even with no window. If no window is on the active Space, the
# deep map is skipped and the report says so.
#
# Usage:
#   map-app.sh                          # print to stdout
#   map-app.sh references/app-ui-map.md # write to a file
#   map-app.sh new-map.md old-map.md    # write new map AND diff vs old map
#
# Env:
#   COPILOT_PID   Exact Copilot process to map. Required when multiple
#                 Copilot app instances are running.
set -euo pipefail

app="/Applications/GitHub Copilot.app"
ver="$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
out="${1:-}"
prev="${2:-}"
target_pid="${COPILOT_PID:-}"

if [ -n "$target_pid" ] && ! [[ "$target_pid" =~ ^[0-9]+$ ]]; then
  echo "COPILOT_PID must be numeric: $target_pid" >&2
  exit 1
fi

map="$(osascript - "$target_pid" <<'AS'
on run argv
set targetPidText to item 1 of argv
set targetPid to 0
if targetPidText is not "" then set targetPid to targetPidText as integer
set nl to linefeed
tell application "System Events"
  if targetPidText is not "" then
    set targetProcess to missing value
    repeat with candidateProcess in every application process
      try
        if (unix id of candidateProcess) is targetPid then
          set targetProcess to candidateProcess
          exit repeat
        end if
      end try
    end repeat
  else
    set matchingProcesses to every application process whose name is "GitHub Copilot"
    if (count of matchingProcesses) is not 1 then error "Set COPILOT_PID when multiple GitHub Copilot instances are running."
    set targetProcess to item 1 of matchingProcesses
  end if
  if targetProcess is missing value then return "Target GitHub Copilot process is not running."

  tell targetProcess
    if targetPidText is not "" then
      set frontmost to true
      delay 1
    end if
    set out to "## Menus" & nl
    repeat with mbi in (menu bar items of menu bar 1)
      set itemNames to ""
      try
        set itemNames to (name of every menu item of menu 1 of mbi) as text
      end try
      set out to out & "- **" & (name of mbi) & "**: " & itemNames & nl
    end repeat

    set wc to (count of windows)
    set out to out & nl & "## Windows" & nl & "count=" & wc & nl
    try
      set out to out & "names=" & ((name of every window) as text) & nl
    end try

    if wc > 0 then
      set out to out & nl & "## Front window named controls (capped at 150)" & nl
      try
        set allItems to entire contents of window 1
        set n to 0
        repeat with elem in allItems
          set r to ""
          set nm to ""
          try
            set r to role of elem
          end try
          try
            set nm to name of elem
          end try
          if nm is not "" and nm is not "missing value" then
            set n to n + 1
            set out to out & "- " & r & ": " & nm & nl
          end if
          if n > 150 then exit repeat
        end repeat
      end try
    else
      set out to out & nl & "(No window on the active Space; deep map skipped. Move the app to this desktop to map controls.)" & nl
    end if
    return out
  end tell
end tell
end run
AS
)"

doc="# GitHub Copilot app UI Map

- app_version: ${ver}
- generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- note: menus are always mapped; window controls require the app visible on the active Space.

${map}"

if [ -n "$out" ]; then
  printf '%s\n' "$doc" > "$out"
  echo "Wrote UI map to $out (app v${ver})" >&2
  if [ -n "$prev" ] && [ -f "$prev" ]; then
    echo "" >&2
    echo "=== changes vs ${prev} (ignoring the generated timestamp) ===" >&2
    diff <(grep -v '^- generated:' "$prev") <(grep -v '^- generated:' "$out") || true
  fi
else
  printf '%s\n' "$doc"
fi
