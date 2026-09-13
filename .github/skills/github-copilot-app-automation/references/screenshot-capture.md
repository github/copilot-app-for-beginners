# Screenshot Capture and WebP Optimization

## Goal

Capture visible GitHub Copilot app states for course material:

- Save a **PNG** as the high-quality source artifact.
- Save a **WebP** optimized version for web delivery.
- Make both files exactly **1920x1080**.
- Add a **2px `#cccccc` border** inside the image edges.
- Reset display zoom, then zoom in exactly twice before preparing the screen.
- Enable and verify **Streamer Mode** before preparing the screen.
- Remove the app version from Settings screenshots after capture.
- Add ordered red number callouts when one image shows multiple controls that
  the reader must select in sequence.
- Keep screenshots deterministic and safe by using a known separate session that is already visible, or by getting explicit approval before changing the visible App window.

## Dedicated Persona Instance

For each course screenshot, launch a new process from the persistent, signed-in
`demo` persona and verify the exact local training repository:

```bash
SK=.github/skills/github-copilot-app-automation/sample_codes/macos-accessibility
PERSONA="demo"
REPO="$HOME/Desktop/projects/copilot-app-for-beginners"
COPILOT_PID="$(bash "$SK/prepare-persona.sh" "$PERSONA" "$REPO" 60)"
```

The preparation workflow:

- Requires an existing signed-in persona home.
- Keeps login and account state in `CopilotPersonas/demo`.
- Starts a new app instance with `open -na`.
- Finds the new process instead of reusing an existing Copilot process.
- Switches only that process to full screen.
- Resets display zoom and zooms in twice.
- Enables and verifies Streamer Mode so unreleased features are hidden.
- Verifies that the persona is signed in.
- Opens the exact repository path through the native folder picker if needed.
- Verifies that the repository name appears in the selected process.
- Prints its process ID for exact capture targeting.

The separate `HOME` isolates app files, but it does not isolate credentials in
the macOS Keychain. The new instance can still show the signed-in account name
and avatar. Process-specific capture reads the profile control, replaces the
person's name with **Copilot Dev**, and keeps the avatar. It also replaces a
visible account handle or repository owner with **copilotdev** when that value
matches the normalized profile name. It does not hard-code real names or
replace unrelated people or organizations. On Settings screens, it removes
the displayed app version because that value changes frequently.

The automation caller needs macOS Accessibility permission to switch the new
window to full screen. Full-screen mode creates or activates a separate macOS
Space, so wait for the transition before navigating or capturing.

Do not use `navigate_to` or another app/session API to prepare this window.
Those APIs belong to the Copilot instance that hosts the agent and can navigate
the wrong instance. Use Accessibility controls selected from the returned
process ID.

After a successful and verified capture, close only the temporary process:

```bash
bash "$SK/cleanup-persona.sh" "$PERSONA" "$COPILOT_PID"
```

The cleanup script stops only the supplied GitHub Copilot process. It preserves
the persona home, account login, and verified project setup.

## Ground Capture in Course Content

Before opening controls, extract the Markdown section around the image:

```bash
python3 "$SK/screenshot-context.py" \
  01-tour-the-app/README.md \
  assets/app-quick-chat.webp
```

Use that output as the capture specification. Check:

- The section heading identifies the correct app surface.
- Steps before the image identify controls that must already be selected.
- Steps after the image identify menus or fields that must remain visible.
- Current Accessibility labels match the words in the course.
- Numbered callouts, if used, follow the order in the nearby instructions.

Use callouts only when all of these conditions are true:

- One screenshot shows two or more controls that the reader must select.
- The controls are visible together in the captured state.
- The nearby text gives the same action order and names each callout.

Do not add callouts to single-action screenshots, output examples, result
tables, terminal evidence, or images that only illustrate a concept.

If a current label differs from the course, update the directly related text.
Do not reproduce an obsolete UI to keep old text unchanged.

## Hidden Session Limitation

macOS screenshot capture requires pixels from a visible display/window. A hidden, background-only, minimized, or API-only Copilot App session cannot be captured with `screencapture` unless the App provides a future render/export API.

For hidden-session tasks:

- Do not call `navigate_to` just to take a screenshot.
- Do not foreground the user's current App window without explicit approval.
- Verify hidden work with `get_session`, session events, and filesystem state.
- Report the limitation plainly when the requested screenshot and hidden execution conflict.

## Required macOS Permissions

Two macOS privacy gates may apply:

- **Accessibility**: required to locate the GitHub Copilot window and read its position/size.
- **Screen Recording**: may be required by `screencapture` to capture app contents.

If a capture is blank, denied, returns `could not create image from display`, or prompts the user, stop and have the user grant permission to the automation caller. Do not bypass macOS privacy controls.

## Local Tool Chain

Observed available tools on this machine:

```text
screencapture=/usr/sbin/screencapture
osascript=/usr/bin/osascript
sips=/usr/bin/sips
cwebp=/opt/homebrew/bin/cwebp
magick=/opt/homebrew/bin/magick
ffmpeg=/opt/homebrew/bin/ffmpeg
pngquant=/opt/homebrew/bin/pngquant
```

Preferred conversion order:

1. `cwebp -lossless -q 82 -m 6 -metadata none source.png -o output.webp`
2. `magick source.png -strip -define webp:lossless=true -quality 82 output.webp`
3. `ffmpeg -i source.png -c:v libwebp -lossless 1 -q:v 82 output.webp`

`sips` is useful for reading dimensions but did not advertise WebP conversion support in the local probe.

## Capture Strategy

Use Accessibility to get the window position and size:

```applescript
tell application "System Events"
  tell process "GitHub Copilot"
    set frontmost to true
    set windowPosition to position of window 1
    set windowSize to size of window 1
  end tell
end tell
```

Then call:

```bash
screencapture -x -R "x,y,width,height" output.png
```

Notes:

- `-x` disables the screenshot sound.
- Rectangle capture is used because Accessibility exposes bounds reliably; exact window id capture would require a lower-level CGWindow lookup.
- On multi-display or Retina setups, validate the first capture. If the crop is offset, capture the full screen once to determine coordinate behavior.

## File Naming

Use descriptive, sortable names:

```text
assets/screenshots/01-tour-the-app-quick-chat.png
assets/screenshots/01-tour-the-app-quick-chat.webp
```

For research artifacts:

```text
~/.copilot/session-state/<session>/files/screenshots/<timestamp>-copilot-app.png
~/.copilot/session-state/<session>/files/screenshots/<timestamp>-copilot-app.webp
```

## Recommended Workflow

1. Extract the image context with `screenshot-context.py`.
2. Launch a new process from the signed-in `demo` persona with
   `prepare-persona.sh`.
3. Confirm that the pre-step reset display zoom, zoomed in twice, and verified
   Streamer Mode as enabled. Then use process-scoped Accessibility to reach the
   required state.
4. Wait 1-2 seconds for UI to settle.
5. Run `capture-window.sh` with the process ID returned by
   `prepare-persona.sh`. For a multi-action screenshot, add repeated
   `--callout NUMBER:X:Y` arguments. Coordinates use the final 1920x1080 image:

   ```bash
   bash "$SK/capture-window.sh" 00-setup/assets app-add-project 40 \
     "$COPILOT_PID" \
     --callout 1:472:324 \
     --callout 2:743:501
   ```

6. Confirm that the callout numbers match the nearby instructions. Place each
   circle next to its control without covering the control label or icon. The
   standard style is a 26px-radius `#ff594b` circle with a white number.
7. Confirm that profile text shows **Copilot Dev**, the avatar remains, and any
   matching personal repository owner shows **copilotdev**.
8. Confirm that the PNG and WebP are both exactly 1920x1080.
9. Confirm that both files have a 2px `#cccccc` inside border.
10. For Settings screens, confirm that no app version remains visible.
11. Inspect file sizes and image dimensions.
12. Review for other private data before moving images into course assets.
13. Run `cleanup-persona.sh` after verification.

## Example

```bash
SK=.github/skills/github-copilot-app-automation/sample_codes/macos-accessibility
PERSONA="demo"
COPILOT_PID="$(bash "$SK/prepare-persona.sh" \
  "$PERSONA" "$HOME/Desktop/projects/copilot-app-for-beginners" 60)"

# Navigate this new instance to the required state, then capture it.
bash "$SK/capture-window.sh" assets/screenshots 01-tour-the-app-session-ui 40 "$COPILOT_PID"
bash "$SK/cleanup-persona.sh" "$PERSONA" "$COPILOT_PID"
```

This creates:

```text
assets/screenshots/01-tour-the-app-session-ui.png
assets/screenshots/01-tour-the-app-session-ui.webp
```

## Recommended: capture by window id (robust)

The Accessibility-rectangle method above can fail on this WebKit-backed app when
`System Events` reports `count of windows = 0` even though a window is visible
(observed on app v1.0.4). The more reliable method captures by CoreGraphics
window id and polls until the window appears. When a process ID is supplied, it
only considers windows owned by that process:

```bash
bash sample_codes/macos-accessibility/capture-window.sh \
  <chapter>/assets <base-name> 40 "$COPILOT_PID"
```

It uses [find-copilot-window.swift](../sample_codes/macos-accessibility/find-copilot-window.swift)
(CoreGraphics) to locate the window id. For a process-specific capture, it
reactivates that process and its full-screen Space immediately before polling.
It then runs `screencapture -x -l <id>` plus a WebP encode and warns if the
capture looks blank (a sign Screen Recording is denied).

When a process ID is supplied, `capture-window.sh` also:

1. Reads the profile control from the exact app process.
2. Derives the person's display name without a hard-coded name list.
3. Finds repository owners whose normalized value matches that display name.
4. Uses OCR to replace the display name with **Copilot Dev** and matching
   owners with **copilotdev**.
5. Verifies that OCR no longer finds the original identity text.
6. Removes the displayed app version when the screenshot shows Settings.
7. Resizes the sanitized PNG and WebP to exactly 1920x1080, adds the required
   2px `#cccccc` inside border, and verifies both.

When `--callout` arguments are supplied, the script adds the badges after
sanitization and 1920x1080 finalization, then encodes the annotated PNG as
WebP. Callout numbers must be consecutive from 1. At least two callouts are
required.

The script removes a Settings version and enforces 1920x1080 even when no
process ID is supplied. Identity discovery requires a process ID, so course
captures must still pass the exact persona process ID.

Only text bounding boxes are changed, so the profile avatar remains visible.
If OCR cannot locate a detected profile name, capture fails closed and keeps
the raw PNG for manual review.

## macOS Spaces constraint (important)

CoreGraphics and `screencapture` only see windows on the **currently active
macOS Space**. If the Copilot app is on a different desktop/Space, or on a
display the capture context cannot reach, no window is found and nothing can be
captured — even though the window is "open." Drag the app onto the same desktop
as the terminal running the capture, then retry. `capture-window.sh` polls for
the duration of its timeout, so you can move the window while it waits.

## Use a sanitized training account

Real captures expose live project names, session titles, prompts, diffs, and
possibly tokens. Capture from a sanitized training account connected to the
training fork (with `node .github/scripts/setup-training-scenarios.js --yes`
run), and review every image before committing. See
[missing-screenshots.md](missing-screenshots.md) for the full shot list and
which states need seeded data.

## Map first

After launching the persona, run
[map-app.sh](../sample_codes/macos-accessibility/map-app.sh) with its process ID
to record the actual menus and named controls before writing capture steps:

```bash
COPILOT_PID="$COPILOT_PID" bash "$SK/map-app.sh"
```

Re-run it after an app update to diff exactly what changed.
