---
name: check-screenshots-content
description: Verify GitHub Copilot app screenshots match the course content. Use when running /check-screenshots-content, or when asked to confirm that app- prefixed screenshots in chapter assets folders are consistent with the README labels, button names, menu items, dialog options, and step-by-step instructions that reference them.
---

# Check Screenshots Content

Use this skill to confirm that the **app screenshots** in the course stay in sync
with the **course text** that describes them. It loads every app screenshot,
reads the UI text out of each image, and cross-checks that text against the
chapter READMEs that embed or describe it.

## Convention This Skill Assumes

- App screenshots (real GitHub Copilot app captures, dark theme) are named
  **`app-<topic>.webp`** and live in a chapter's **`assets/`** folder, for
  example `03-development-workflows/assets/app-workspace-panel.webp`.
- Illustrations and analogy art (recording-studio theme, flow diagrams) do **not**
  use the `app-` prefix, so this skill ignores them.

If an obvious app screenshot is missing the `app-` prefix, flag it so the author
can rename it (and update the README image reference).

## What To Check

For every `app-*` screenshot, compare the **exact on-screen text** to how the
course refers to it:

1. **Label casing and wording** — UI labels must match the screenshot verbatim,
   including casing. For example the sidebar shows `My work` (lowercase "w"),
   `Home`, `Automations`, `Search`, `Sessions`, `Quick chats`. Flag any course
   text that writes `My Work`, `Quick Chats`, etc.
2. **Buttons, menu items, and dialog options** — names the README tells the user
   to click must match the screenshot, e.g. `Create from…`, `Toggle review panel`,
   `Exit plan mode and I will prompt myself`, `Local folder or repository`,
   `GitHub repository`, `Repository URL`.
3. **Mode and control names** — `Interactive`, `Plan`, `Autopilot` plus their
   descriptions, and the model / reasoning-effort controls.
4. **Image embed and alt text** — every `app-*` image is embedded by at least one
   README (no orphan images), every `![...](...app-...)` link resolves to a file
   that exists (no broken paths), and the alt text matches what the image shows.
5. **Instruction ↔ screenshot coverage** — when a README step names a UI
   affordance that a screenshot does show, the wording must match. When a step
   names an affordance that **no** screenshot shows, report it as a coverage gap
   (these are often already marked with `<!-- app-screenshot: ... -->` or
   `<!-- MANUAL STEP TO VERIFY ... -->` comments).

Treat
[`.github/skills/github-copilot-app-automation/references/app-ui-map.md`](../github-copilot-app-automation/references/app-ui-map.md)
as the canonical source for UI label spelling and casing. If a screenshot and the
UI map disagree, trust the screenshot and note that the UI map needs a refresh.

## Workflow

1. **Discover and prepare the images.** Run the helper, which lists every
   `app-*` screenshot and writes a PNG copy you can load (some `.webp` files do
   not load directly in the image view tool):

   ```bash
   bash .github/skills/check-screenshots-content/sample_codes/list-app-screenshots.sh
   ```

   Fallback if you prefer to do it by hand: glob `*/assets/app-*` and convert any
   `.webp` with `sips -s format png <file>.webp --out /tmp/<name>.png` before viewing.

2. **Read each screenshot.** View the PNG and transcribe the visible UI text:
   labels, button captions, menu items, dialog headings and options, mode names,
   tooltips, and any keyboard shortcuts.

3. **Find where the course references it.** For each image, grep the chapters for
   its filename to find the embedding README and the surrounding steps, e.g.
   `grep -rn "app-workspace-panel" .` Then read the alt text and the nearby
   numbered steps.

4. **Cross-check** the transcribed text against the README using the rules in
   *What To Check* above. Also scan the whole course for the visible labels to
   catch casing drift in chapters that do not embed the image
   (e.g. `grep -rn "My Work" .`).

5. **Report** findings (see *Output*). Do not edit images or rename files as part
   of the check. Only propose or apply text fixes if the user asks.

## Output

Produce a concise, grouped report:

- **✅ Matches** — screenshot ↔ course text agreements worth confirming (brief).
- **⚠️ Discrepancies** — concrete mismatches, each with the screenshot, the
  expected on-screen text, the actual course text, and a `file:line` citation.
- **📷 Coverage gaps** — README steps that name UI with no supporting screenshot,
  and any obvious app screenshot missing the `app-` prefix.

Keep citations exact (`path/README.md:NN`) so fixes are easy to apply.

## Safety and Notes

- Read-only by default: analyze and report; only change course text when asked.
- Convert `.webp` to PNG in a temp dir (`/tmp`), never write derived images into
  the repo.
- Screenshots may contain account names, private repo names, or paths. Do not
  copy private data into the report; describe the UI generically.
- Casing matters: product labels use the app's exact sentence case
  (e.g. `My work`, `Quick chats`), even inside Title Case headings.
