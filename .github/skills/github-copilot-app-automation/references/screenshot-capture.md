# Screenshot Capture and WebP Optimization

## Goal

Capture visible GitHub Copilot app states for course material:

- Save a **PNG** as the high-quality source artifact.
- Save a **WebP** optimized version for web delivery.
- Make full-window files exactly **1920x1080**. A crop keeps the size of its
  crop rectangle.
- Add a **2px `#cccccc` border** inside the image edges, also on crops.
- Remove the macOS window buttons (close, minimize, zoom) from the top-left
  corner and move the sidebar icon into their place, so the screenshot does
  not show the operating system. `capture-window.sh` runs
  `hide-window-controls.py` for this.
- Do not let the window corners turn black. The window has transparent
  rounded corners. Put the image on white before any RGB conversion or resize.
  `capture-window.sh` checks the corners before it adds annotations, and stops
  if it finds dark pixels.
- Capture a standard 1920x1080-point window, not full screen.
- Reset display zoom, then zoom in exactly three times (150%) before preparing the
  screen.
- Enable and verify **Streamer Mode** before preparing the screen.
- Remove the app version from Settings screenshots after capture.
- Add ordered red number callouts when one image shows multiple controls that
  the reader must select in sequence. Use a red highlight box for one item.
- Keep screenshots deterministic and safe by using a known separate session that is already visible, or by getting explicit approval before changing the visible App window.

## Dedicated Persona Instance

For each course screenshot, launch a new process from the persistent, signed-in
`demo` persona and verify the exact local training repository:

```bash
SK=.github/skills/github-copilot-app-automation/sample_codes/macos-accessibility
PERSONA="demo"
# The local clone of the training fork, not the upstream course repository.
REPO="$HOME/copilot-app-for-beginners"
COPILOT_PID="$(bash "$SK/prepare-persona.sh" "$PERSONA" "$REPO" 60)"
```

The preparation workflow:

- Requires an existing signed-in persona home.
- Keeps login and account state in `CopilotPersonas/demo`.
- Starts a new app instance with `open -na`.
- Finds the new process instead of reusing an existing Copilot process.
- Sets only that process's main window to a standard 1920x1080-point frame,
  centered on its display.
- Resets display zoom, zooms in three times, and measures a sidebar control to
  confirm the 150% zoom. With `COPILOT_CAPTURE_DISPLAY=builtin`, it uses the
  built-in laptop display and two zoom steps (125%). It retries and fails if it cannot confirm the zoom.
- Enables and verifies Streamer Mode so unreleased features are hidden.
- Verifies that the persona is signed in.
- Opens the exact repository path through the native folder picker if needed.
- Verifies that the repository name appears in the selected process.
- Dismisses transient banners (only buttons on a safe allowlist) and moves the
  pointer away from the content.
- Prints its process ID for exact capture targeting.

The separate `HOME` isolates app files, but it does not isolate credentials in
the macOS Keychain. The new instance can still show the signed-in account name
and avatar. Process-specific capture reads the profile control, replaces the
person's name with **Copilot Dev**, and keeps the avatar. It also replaces a
visible account handle or repository owner with **copilotdev** when that value
matches the normalized profile name, also inside paths and branch names. The
macOS account name and the machine name, which terminal prompts and paths can
show, become **copilotdev** and **copilot-dev-mac**. It does not hard-code real
names or replace unrelated people or organizations. On Settings screens, it
removes the displayed app version because that value changes frequently.

The identities are cached for each process the first time the sidebar is
visible, because an open dialog can hide the sidebar from Accessibility.
`cleanup-persona.sh` removes that cache.

The automation caller needs macOS Accessibility permission to set the window
frame and zoom. Do not use full screen for course captures: while the app is
active, macOS can draw the menu bar and title bar over the app content.

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

When you retake an existing image, view the old image first. Recreate its
numbered callouts, highlight boxes, and arrows on the same controls at their
new positions, and keep a similar crop. If the old target no longer exists
(for example, a **Running...** state that now ends in seconds), point at the
nearest element that shows the same result, and say so in your report.

## Prepare Transient UI States

Many course states are hard to create with a plain button press. Use
[prepare-copilot-state.swift](../sample_codes/macos-accessibility/prepare-copilot-state.swift)
and [locate-copilot-element.swift](../sample_codes/macos-accessibility/locate-copilot-element.swift):

| Need | Approach |
|---|---|
| Show a hover-only control, such as **New chat** (+) on the **Chats** row or **Create from** on a project row | `focus <label>`: a focused control also shows its focus ring and tooltip |
| Show a menu item as selected | Open the menu, then `highlight-menu-item <label>`. Web menus ignore synthetic pointer moves, so this presses Down until the item is active |
| Fill a field without submitting | `set-value <label> <text>` never presses Return |
| Remove hover effects, tooltips, and focus rings | `park` (add `keep-focus` when the image must show a focused field) |
| Remove promotions and notices | `dismiss-banners` presses only allowlisted buttons such as **Close banner** or **Not now** |
| Place callouts, boxes, and crops | `locate-copilot-element <pid> <label> [role]` prints final 1920x1080 coordinates |

Other observed quirks:

- An open dialog hides the sidebar from Accessibility. Sanitization uses the
  identity cache from an earlier capture of the same process.
- The review panel splitter keeps focus after keyboard resizing. Press Tab,
  then Escape, before capture.
- A first-run learner has no project, so the Projects **+** menu shows no
  **Start session in** group. To show their view, clear **Show in sidebar** on
  the project's Settings page, capture, and then select it again.
- Restore every persona change after capture: hidden projects, installed
  plugins and MCP servers, test automations, and temporary sessions.
- The review panel does not open on the New view. Submit a first prompt so the
  session exists, then open the panel.
- Each capture brings the persona window to the front. A Return key press that
  the user types in another app at that moment goes to the persona. When a
  **Review plan** or **Question** box is waiting, Return submits the selected
  option, and **Approve and implement this plan** starts Autopilot. Capture
  these states quickly, then choose **Exit plan mode and I will prompt myself**
  or delete the session. If an agent starts work by mistake, stop it, check the
  worktree, and delete the session.
- To show the branch name `copilotdev-…` in a new session, set **Settings** >
  **Sessions** > **Default branch prefix** to `copilotdev-` before you start the
  session, and restore `%username%-` after capture. The sanitizer replaces
  names in most text, but faint or partly hidden branch text can stay
  readable.
- Long descriptions in `/` and `@` typeahead rows scroll sideways after about
  half a second. To show the start of the text, type the command and capture
  within about 0.3 seconds, or capture with `screencapture -l <window id>` and
  then run the sanitizer and finalizer yourself.
- The Terminal prompt shows the macOS user and computer name. Before capture,
  run `PROMPT='%1~ %# '` and `clear` in the Terminal tab so the prompt shows
  only the folder name.
- A new custom agent file loads only after the app restarts. Close the persona
  with `cleanup-persona.sh`, then start it again with `prepare-persona.sh`.
- Persona workspace choices persist. Note the workspace selector value
  (**New worktree** or **Current checkout**) before you change it, and restore
  it after capture.
- On the sign-in and onboarding screens, `launch-persona.sh` cannot set the
  zoom and prints no process ID. Find the persona process by its `HOME` value.
- A website install button opens a `ghapp://` link. Do not use `open` with that
  link, because macOS sends it to the default app instance, which can be the
  user's own app. Send it only to the persona's process ID. The agent's host
  app cannot get the macOS Automation permission, so use a small signed helper
  app that declares `NSAppleEventsUsageDescription`. macOS then asks the user
  to **Allow** it once.
- All app instances use the same WebKit storage in the real
  `~/Library/WebKit/com.github.githubapp` folder. Persona activity can change
  some web UI state in the user's own app, such as the repository selection in
  the Issues and Pull requests views.
- `tesseract` cannot read a file in `/tmp`, because it resolves `/tmp` to
  `/private/tmp` and then fails. It prints an error, and a scan that greps its
  output reports no matches. Pipe the image instead
  (`dwebp -quiet a.webp -o - | tesseract stdin -`), or keep files in the
  session folder. Treat empty OCR output as a failure, not a clean result.
- Typeahead rows, project picker rows, and some option buttons report wrong
  Accessibility frames (for example 955x911). The center of such a frame can be
  outside the persona window, and a real click there goes to another app.
  Click the visible row instead, and refuse any point outside the persona
  window frame.
- `/chronicle standup` reports every session of the signed-in account from the
  last day, including sessions from other computers. Scroll the chat so only
  the course session shows, and run the OCR privacy check for the names of
  other sessions.
- The sanitizer sometimes cannot find the profile name with OCR. It then keeps
  only `<name>.raw.png`. Delete that raw file at once, and capture again.
- When the app stages an update, a **Ready to update** toast (Restart now,
  Later) appears at the bottom right, and the files are in
  `<persona>/.copilot/updater`. Select **Later**. Before you close the persona,
  delete `staged-update.bin` and `staged-manifest.json`, so the persona cannot
  install the update into the shared `/Applications` app bundle.
- Chapter 06 Feature Workbench timing (Claude Opus 5.5): `/create-canvas`
  takes about 5 minutes. **Generate plan** shows **Working...** for only about
  15 seconds, or about 3 seconds when the agent reuses an earlier plan, so
  capture within 2 seconds, in a fresh session. **Run baseline** ends in about
  6 seconds, so capture the finished state with the test tool call expanded.
  **Browser validation** can start the dev server as an attached background
  task. The turn then stays open, and the action stays on **Working...** (after
  20 minutes it shows **Timed out**) until you stop the server in
  **Background**. The agent can also install `playwright-core` in `/tmp`.
  Check that it deletes that folder.

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
3. Confirm that the pre-step set the capture frame, confirmed the 150% zoom,
   and verified Streamer Mode as enabled. Then use process-scoped Accessibility
   to reach the required state.
4. Wait 1-2 seconds for UI to settle.
5. Run `capture-window.sh` with the process ID returned by
   `prepare-persona.sh`. For a multi-action screenshot, add repeated
   `--callout NUMBER:X:Y` arguments. For one item, add `--box
   LEFT:TOP:RIGHT:BOTTOM`. To keep only a detail area, add `--crop
   LEFT:TOP:RIGHT:BOTTOM`. All coordinates use the final 1920x1080 image:

   ```bash
   bash "$SK/capture-window.sh" 00-setup/assets app-add-project 40 \
     "$COPILOT_PID" \
     --callout 1:372:338 \
     --callout 2:585:437
   ```

6. Confirm that the callout numbers match the nearby instructions. Place each
   circle next to its control without covering the control label or icon. The
   standard style is a 26px-radius `#ff594b` circle with a white number.
7. Confirm that profile text shows **Copilot Dev**, the avatar remains, and any
   matching personal repository owner, path, or branch name shows
   **copilotdev**. Zoom in on each replaced span.
8. Confirm that the PNG and WebP are both exactly 1920x1080, or the crop size.
9. Confirm that both files have a 2px `#cccccc` inside border.
10. For Settings screens, confirm that no app version remains visible.
11. Inspect file sizes and image dimensions.
12. Review for other private data before moving images into course assets.
13. Restore persona changes, then run `cleanup-persona.sh` after verification.

## Example

```bash
SK=.github/skills/github-copilot-app-automation/sample_codes/macos-accessibility
PERSONA="demo"
COPILOT_PID="$(bash "$SK/prepare-persona.sh" \
  "$PERSONA" "$HOME/copilot-app-for-beginners" 60)"

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
activates that process immediately before polling, waits for transient system
indicators to fade (`COPILOT_CAPTURE_SETTLE_SECONDS`, default 2), and fails
with exit code 5 if a Siri waveform orb is visible. It then runs
`screencapture -x -o -l <id>` (without the window shadow) plus a WebP encode and
warns if the capture looks blank (a sign Screen Recording is denied).

When a process ID is supplied, `capture-window.sh` also:

1. Reads the profile control from the exact app process.
2. Derives the person's display name without a hard-coded name list.
3. Finds repository owners whose normalized value matches that display name.
4. Uses OCR (a 3x grayscale copy) to replace the display name with **Copilot
   Dev**, matching owners with **copilotdev**, and the local account and
   machine names with **copilotdev** and **copilot-dev-mac**. It redraws the
   text in the measured font, size, weight, and color, and moves the rest of
   the line so the spacing stays the same.
5. Verifies with two more OCR passes that the original identity text is gone.
6. Removes the displayed app version when the screenshot shows Settings.
7. Resizes the sanitized PNG to exactly 1920x1080 and adds the required 2px
   `#cccccc` inside border.

When `--callout`, `--box`, or `--arrow` arguments are supplied, the script adds
the badges, outlines, and arrows after sanitization and 1920x1080 finalization.
Callout numbers must be consecutive from 1, and one callout alone is rejected.
Boxes are 4px `#ff594b` outlines and need no callouts. Arrows are 5px
`#ff594b` lines with a filled head at `HEAD_X:HEAD_Y`, at least 44px long.
When `--crop` is supplied, the script then cuts out that rectangle and adds the
border again. Finally, it encodes the PNG as WebP and verifies the size and
border of both files.

To try callout positions without a retake, capture once without callouts. Then
copy the PNG, run `add-step-callouts.py` on the copy with 1920x1080
coordinates, run `finalize-screenshot.py <png> --crop L:T:R:B`, and encode it
with `cwebp -lossless -q 82 -m 6 -metadata none`.

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

With `COPILOT_CAPTURE_DISPLAY=builtin`, the persona window opens on the built-in
laptop display. The active Space of each display is visible, so capture works
while you work on other displays. Set the same variable for `capture-window.sh`
so it does not activate the persona.

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
