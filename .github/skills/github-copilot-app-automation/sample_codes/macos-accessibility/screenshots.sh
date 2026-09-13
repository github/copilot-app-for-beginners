#!/usr/bin/env bash
#
# Dynamic, generic helper for the course's app-screenshot placeholders.
#
# The chapter READMEs are the SINGLE SOURCE OF TRUTH. Nothing about individual
# shots is hardcoded here: pending screenshots are discovered at runtime from
# `<!-- app-screenshot: ... -->` comments, so this keeps working as chapters add,
# edit, or remove placeholders over time.
#
# Subcommands:
#   list                         List every pending placeholder (index, file:line, description).
#   next [INDEX]                 Show one pending shot (default 1): description, a derived
#                                slug, the assets dir, and the exact capture/embed commands.
#   embed FILE LINE NAME [ALT]   Replace the placeholder at FILE:LINE with an image embed
#                                `![ALT](assets/NAME)`. ALT defaults to the description.
#
# Capture is semi-automated (a human navigates the dedicated persona instance;
# the CLI has no `navigate_to`), so the loop is: next -> prepare persona -> read
# context -> get that instance to the required state -> capture -> review -> embed.
#
# Env:
#   SCREENSHOT_ROOT   Repo root to scan (default: current directory).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="${SCREENSHOT_ROOT:-$(pwd)}"
cmd="${1:-list}"
shift || true

HERE="$here" ROOT="$root" python3 - "$cmd" "$@" <<'PY'
import sys, os, re, glob

here = os.environ["HERE"]
root = os.environ["ROOT"]
cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
args = sys.argv[2:]

PLACEHOLDER = re.compile(r"<!--\s*app-screenshot:\s*(.*?)\s*-->")
STOP = {"the","a","an","of","in","on","and","or","with","for","to","showing","show",
        "that","this","its","your","if","available","app","as","such","inside"}

def find_pending():
    items = []
    for f in sorted(glob.glob(os.path.join(root, "[0-9]*", "README.md"))):
        with open(f) as fh:
            for i, line in enumerate(fh, 1):
                m = PLACEHOLDER.search(line)
                if m:
                    items.append((os.path.relpath(f, root), i, m.group(1).strip()))
    return items

def slug(desc):
    d = re.sub(r"^(ADVANCED|INTERMEDIATE):\s*", "", desc, flags=re.I)
    d = re.sub(r"`[^`]*`", "", d)
    words = [w for w in re.findall(r"[A-Za-z0-9]+", d.lower()) if w not in STOP]
    return "app-" + "-".join(words[:5]) if words else "app-screenshot"

def clean_alt(desc):
    return re.sub(r"^(ADVANCED|INTERMEDIATE):\s*", "", desc, flags=re.I).strip()

if cmd == "list":
    items = find_pending()
    if not items:
        print("No pending app-screenshot placeholders. All captured!")
        sys.exit(0)
    print(f"{len(items)} pending app-screenshot placeholder(s):\n")
    for n, (f, i, d) in enumerate(items, 1):
        print(f"{n:>2}) {f}:{i}\n     {d}\n")
    sys.exit(0)

if cmd == "next":
    items = find_pending()
    if not items:
        print("No pending app-screenshot placeholders. All captured!")
        sys.exit(0)
    idx = int(args[0]) if args else 1
    if idx < 1 or idx > len(items):
        print(f"Index out of range (1..{len(items)})")
        sys.exit(1)
    f, i, d = items[idx - 1]
    s = slug(d)
    adir = os.path.join(os.path.dirname(f), "assets")
    skill = os.path.relpath(here, root)
    print(f"pending: {len(items)}   showing #{idx}")
    print(f"file:        {f}")
    print(f"line:        {i}")
    print(f"description: {d}")
    print(f"slug:        {s}")
    print(f"assets_dir:  {adir}")
    print()
    print("Run from the repo root:")
    print(f"  # 1) Read the surrounding instructions and decide whether callouts are required:")
    print(f"  python3 {skill}/screenshot-context.py {f} {s}.webp")
    print(f"  # 2) Prepare a new full-screen demo persona:")
    print(f'  COPILOT_PID="$(bash {skill}/prepare-persona.sh demo "$HOME/Desktop/projects/copilot-app-for-beginners" 60)"')
    print(f"  # 3) Get that instance to the required state, then capture only its window:")
    print(f'  bash {skill}/capture-window.sh {adir} {s} 40 "$COPILOT_PID"')
    print("  #    If one image shows multiple actions, append ordered callouts:")
    print('  #    --callout 1:X:Y --callout 2:X:Y')
    print(f"  # 4) Review {adir}/{s}.webp for private data, then embed it:")
    print(f'  bash {skill}/screenshots.sh embed {f} {i} {s}.webp "{clean_alt(d)}"')
    sys.exit(0)

if cmd == "embed":
    if len(args) < 3:
        print("usage: embed FILE LINE NAME [ALT]")
        sys.exit(1)
    f, line_s, name = args[0], args[1], args[2]
    alt = args[3] if len(args) > 3 else None
    path = f if os.path.isabs(f) else os.path.join(root, f)
    line_no = int(line_s)
    with open(path) as fh:
        lines = fh.readlines()
    if line_no < 1 or line_no > len(lines):
        print("line out of range")
        sys.exit(1)
    target = lines[line_no - 1]
    m = PLACEHOLDER.search(target)
    if not m:
        print(f"No app-screenshot placeholder at {f}:{line_no}. Found: {target.strip()!r}")
        sys.exit(1)
    if alt is None:
        alt = clean_alt(m.group(1))
    name = os.path.basename(name)
    indent = re.match(r"\s*", target).group(0)
    lines[line_no - 1] = f"{indent}![{alt}](assets/{name})\n"
    with open(path, "w") as fh:
        fh.writelines(lines)
    print(f"Embedded assets/{name} at {f}:{line_no}")
    sys.exit(0)

print(f"unknown subcommand: {cmd}  (use: list | next | embed)")
sys.exit(1)
PY
