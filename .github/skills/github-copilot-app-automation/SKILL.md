---
name: github-copilot-app-automation
description: Automate and research the GitHub Copilot app desktop experience. Use for driving Copilot App sessions, creating isolated app experiments, mapping app UI/accessibility controls, taking app screenshots, saving PNG captures, optimizing WebP images, testing prompts without submitting, using app/session APIs, canvases, automations, macOS Accessibility, AppleScript, and safe end-to-end Copilot App workflow probes.
---

# GitHub Copilot app Automation

Use this skill when the task is about **driving, testing, mapping, or experimenting with the GitHub Copilot app**. Prefer app/session APIs first, then app-native canvases/automations, and use GUI Accessibility only when the visible desktop UI itself must be exercised.

## Where to Run This

This skill's power depends heavily on where the agent runs:

| Context | Session/app APIs | Capture reliability | Best for |
|---|---|---|---|
| **Inside the GitHub Copilot app agent** (recommended) | Available for the host instance. They do not select a separately launched persona. | High when the agent launches, drives, and captures the persona by process ID | End-to-end screenshot capture with a dedicated persona |
| **GitHub Copilot CLI** (terminal) | Not available | Low/manual — a human must navigate the app, and its window must be on the same macOS Space as the terminal | Read-only mapping (`map-app.sh`), the dynamic `screenshots.sh` list/embed flow, and one-off captures of an already-visible window |

For course screenshots, **drive this from inside the app**, but do not use the
host instance as the screenshot target. Launch the dedicated persona below,
then use process-scoped Accessibility and capture. The shell scripts here run
in both contexts because the app agent is built on Copilot CLI.

Regardless of context: pixels still come from `screencapture` (there is no pure render/export API yet, so the window must be visible), Screen Recording permission is required, captures must come from a **sanitized training account** on the training fork, and advanced features (Agent Merge, cloud automations) stay policy/billing-gated.

For each screenshot, launch a new app process from the persistent, signed-in
`demo` persona instead of creating a new persona or reusing an open process:

```bash
SK=.github/skills/github-copilot-app-automation/sample_codes/macos-accessibility
PERSONA="demo"
REPO="$HOME/Desktop/projects/copilot-app-for-beginners"
COPILOT_PID="$(bash "$SK/prepare-persona.sh" "$PERSONA" "$REPO" 60)"
```

This keeps the existing login and persona data, starts a separate app process,
switches only that process to full screen, resets the display zoom and zooms in
twice, enables and verifies **Streamer Mode**, verifies that the account is
signed in, verifies the exact local repository, and returns its process ID. If the
repository is missing, the pre-step opens the exact folder through the native
folder picker and verifies it before capture. A setup failure keeps the process
for inspection and does not return a successful process ID. Do not select a
target by app name when another Copilot instance is open.

Before preparing the visible state, extract the Markdown around the image
reference:

```bash
python3 "$SK/screenshot-context.py" <chapter>/README.md <image-name>
```

Use the section heading, instructions before the image, and instructions after
the image to define the exact screen, open menu, selected item, and callouts.
Do not capture a generic approximation. Confirm that current Accessibility
labels agree with the text. If the app label changed, update the directly
related course text before capture.

Add numbered red callouts when one screenshot shows two or more controls that
the reader must select in order. The nearby instructions must identify each
number, for example, "select **+** (callout 1), then select **Add GitHub
repository** (callout 2)." Do not add callouts to a single-action screenshot,
an output example, or an evidence screenshot.

Keep the process ID and use it for all UI operations and capture. Do not use
`navigate_to` or other app/session APIs to prepare this window because those
APIs can route to the instance that hosts the agent. Drive the persona through
Accessibility selectors scoped to its process ID.

An isolated `HOME` does not isolate credentials stored in the macOS Keychain.
The persona can still show the current GitHub account name and avatar.
Process-specific capture automatically derives the visible profile name from
the accessibility tree and replaces that text with **Copilot Dev**. If an
account handle or repository owner matches the normalized profile name, it
replaces that text with **copilotdev**. It preserves the avatar and unrelated
people and organizations. On a Settings screen, it also removes the displayed
app version. Never hard-code a person's name or an app version. Never treat
the persona name alone as proof that the capture is sanitized.

## Non-Interactive / Hidden-Session Rule

If the user asks for a **fresh**, **separate**, or **hidden** Copilot App instance/session:

- Stay on app/session APIs: `list_projects`, `create_session`, `send_session_message`, `get_session`, and filesystem verification.
- Do **not** call `navigate_to`, foreground `open -a`, menu-bar actions, folder pickers, or Accessibility clicks unless the user explicitly asks to see the App UI.
- Do **not** make the user select a folder or project. If a project cannot be registered through available non-interactive surfaces, report that limitation instead of opening a visible picker.
- For local folders, first make the target folder a distinct repo root when needed (`git init` in the target folder) so the App can distinguish it from a parent repository.
- If a hidden registration attempt is necessary, prefer `open -g -j -a "GitHub Copilot" <folder>` and immediately verify with `list_projects`; if it does not register the project, stop and report the gap.
- A screenshot of a hidden/minimized/background-only session is not possible with macOS `screencapture`; screenshot capture requires a visible window or a future App-provided render/export API. Do not switch the user's current App window just to satisfy a hidden screenshot request.

## Operating Model

Work in layers, from safest to most brittle:

1. **Session orchestration tools**: list projects/sessions, create isolated sessions, message sessions, inspect sessions, navigate to sessions.
2. **App-native surfaces**: canvases, automations, project settings, MCP, skills, issue/PR sessions.
3. **Copilot CLI remote control**: useful for CLI sessions via GitHub.com/GitHub Mobile, not for native app GUI control.
4. **macOS Accessibility/UI scripting**: use AppleScript/System Events for named controls such as `Message`, `Select model`, and `Open changes`.
5. **Screenshot capture**: use Accessibility window bounds plus `screencapture` to save PNGs, then convert to WebP for web delivery.
6. **Low-level GUI clicking**: avoid unless the user explicitly approves and no named accessibility control exists.

## Safety Rules

- **Create a separate session for experiments** unless the user explicitly wants the current session modified.
- For hidden/separate-session tasks, **never navigate the user's visible App window** unless explicitly requested.
- **Never submit a prompt, create a PR, merge, delete, approve permissions, or enable Agent Merge** without explicit user intent.
- For GUI probes, start read-only: enumerate windows, controls, roles, names, and actions.
- For composer tests, type a clearly marked draft and clear it without pressing Return/Enter.
- Avoid pixel-coordinate clicks. Target controls by accessibility role/name/action.
- Do not persist secrets or private UI data in repo files. Store scratch probes in `/tmp` or the session artifact directory.
- Screenshots may contain private repo names, prompts, diffs, terminal output, or tokens. Capture only the requested app state and save course-ready images under an intentional assets folder.
- Expect transient app/window states. Re-discover the window and `AXWebArea` before each UI operation.
- If Accessibility is denied, stop and ask the user to grant access to the automation caller. Do not try to bypass macOS privacy controls.
- If `screencapture` fails or returns a privacy prompt, the automation caller also needs macOS Screen Recording permission.

## Known Local App Facts

Observed on this machine:

- App path: `/Applications/GitHub Copilot.app`
- Bundle id: `com.github.githubapp`
- Bundle version: read dynamically with `map-app.sh`; do not rely on a stored version
- Executable: `/Applications/GitHub Copilot.app/Contents/MacOS/github`
- Binary type: native macOS Mach-O arm64
- Frameworks observed include AppKit and WebKit.
- The desktop app is not obviously Electron/Chromium; do not assume Playwright/CDP control is available.

## Known Accessibility Map

After macOS Accessibility permission was enabled, `System Events` could address the app as process `GitHub Copilot`.

Useful exposed controls:

| Control | Role | Use |
|---|---|---|
| `GitHub Copilot` | `AXWindow` | Main app window |
| `GitHub Copilot` | `AXWebArea` | Main webview-backed app content |
| `Sidebar` | `AXGroup` | Sidebar region |
| `Toggle sidebar` | `AXCheckBox` | Collapse/expand sidebar |
| `Create new project or session` | `AXPopUpButton` | New project/session menu |
| `New session in <project>` | `AXButton` | Project-specific new session entry |
| `Message` | `AXTextArea` | Prompt composer |
| `Select model` | `AXComboBox` | Model picker |
| `Conversation timeline` | `AXGroup` | Main conversation history |
| `Open changes` | `AXButton` | Diff/changes surface |

See [macos-accessibility.md](references/macos-accessibility.md) for scripts and caveats.

## Preferred Workflows

### Map the App Safely

1. Confirm the app is running and discover bundle/process state.
2. Enumerate projects and sessions with app/session tools.
3. Run a read-only Accessibility window/menu probe.
4. Enumerate `AXWebArea` children.
5. Save findings to session artifacts, not the repo, unless the user asked for durable docs.

Use:

- [probe-readonly.applescript](sample_codes/macos-accessibility/probe-readonly.applescript)
- [automation-map.md](references/automation-map.md)

### Test Composer Control Without Submitting

1. Create a separate idle session.
2. Navigate to that session.
3. Focus `AXTextArea name=Message`.
4. Set a draft value directly.
5. Read the value back.
6. Clear it with Command+A and Delete.
7. Verify the returned `cleared-value` is empty.

Use [type-and-clear-draft.applescript](sample_codes/macos-accessibility/type-and-clear-draft.applescript).

### Capture Screenshots for Course Assets

Only use this workflow when the user has agreed the App can be visible or when the target state is already visible in a dedicated App window. Capture from a **sanitized training account** on the training fork — never the user's real private projects.

1. Run `screenshot-context.py` for the referenced image and turn the nearby
   course text into a concrete capture checklist.
2. Launch a new full-screen process from the persistent `demo` persona with
   `prepare-persona.sh`. The pre-step resets zoom, zooms in twice, and enables
   and verifies **Streamer Mode**. It fails closed if Streamer Mode cannot be
   verified. Pass the exact local training repository and keep the returned
   process ID.
3. Map that process with `COPILOT_PID="$COPILOT_PID" map-app.sh` so steps match
   the current app build.
4. Navigate that process to the exact state with Accessibility controls and let
   spinners settle.
5. Capture the window owned by that process ID and convert it to WebP. When the
   image requires ordered callouts, pass each badge in instruction order at its
   final 1920x1080 coordinates:
   ```bash
   bash sample_codes/macos-accessibility/capture-window.sh \
     <chapter>/assets <base-name> 40 "$COPILOT_PID"

   bash sample_codes/macos-accessibility/capture-window.sh \
     00-setup/assets app-add-project 40 "$COPILOT_PID" \
     --callout 1:472:324 --callout 2:743:501
   ```
6. For callout images, confirm that every badge is next to its control, does not
   cover a label or icon, and matches the instruction order. The standard style
   is a 26px-radius `#ff594b` circle with a white number.
7. Keep PNG as the source artifact; use WebP in web/course pages.
8. Confirm that both files are exactly 1920x1080.
9. Confirm that the image has a 2px `#cccccc` border inside its edges.
10. Confirm that the output keeps the avatar, shows **Copilot Dev** instead of a
   person's profile name, and uses **copilotdev** for matching personal
   repository owners.
11. For Settings screenshots, confirm that no app version is visible.
12. Review the screenshot for other private data before committing or
   publishing.
13. Close the exact process with `cleanup-persona.sh` only after the capture is
   verified. Keep the signed-in persona for the next screenshot.

To work through the course's pending shots, discover them dynamically and process one at a time (never hardcode the list): `screenshots.sh list` -> `screenshots.sh next` -> capture -> `screenshots.sh embed`. See [missing-screenshots.md](references/missing-screenshots.md).

Use:

- [screenshot-capture.md](references/screenshot-capture.md) — full method, permissions, and the macOS Spaces constraint
- [missing-screenshots.md](references/missing-screenshots.md) — the generic, one-at-a-time capture workflow (shots are discovered dynamically, never hardcoded)
- [screenshots.sh](sample_codes/macos-accessibility/screenshots.sh) — dynamically `list` / `next` / `embed` the chapters' `<!-- app-screenshot: ... -->` placeholders
- [screenshot-context.py](sample_codes/macos-accessibility/screenshot-context.py) — extracts the course section that defines a screenshot's required state
- [prepare-persona.sh](sample_codes/macos-accessibility/prepare-persona.sh) — launches a new process from a signed-in persona, verifies the exact local repository, and returns the process ID
- [ensure-streamer-mode.swift](sample_codes/macos-accessibility/ensure-streamer-mode.swift) — enables and verifies Streamer Mode before screenshot preparation
- [cleanup-persona.sh](sample_codes/macos-accessibility/cleanup-persona.sh) — stops one exact screenshot process and preserves the signed-in persona
- [launch-persona.sh](sample_codes/macos-accessibility/launch-persona.sh) — low-level launcher used by `prepare-persona.sh`
- [control-copilot-window.swift](sample_codes/macos-accessibility/control-copilot-window.swift) — activates or enters full screen for one exact app process
- [control-copilot-ui.swift](sample_codes/macos-accessibility/control-copilot-ui.swift) — presses one named Accessibility control in an exact app process
- [find-private-identities.swift](sample_codes/macos-accessibility/find-private-identities.swift) — derives profile names and matching personal repository owners without hard-coded identities
- [sanitize-screenshot.sh](sample_codes/macos-accessibility/sanitize-screenshot.sh) — replaces identity text while preserving avatars
- [app-ui-map.md](references/app-ui-map.md) — sanitized factual UI map (menus, sidebar, composer controls), regenerable via map-app.sh
- [capture-window.sh](sample_codes/macos-accessibility/capture-window.sh) — recommended: process-filtered CoreGraphics window capture + WebP
- [finalize-screenshot.py](sample_codes/macos-accessibility/finalize-screenshot.py) — enforces 1920x1080 output and adds the required 2px `#cccccc` inside border
- [add-step-callouts.py](sample_codes/macos-accessibility/add-step-callouts.py) — adds ordered red step badges to a finalized screenshot when one image shows multiple actions
- [find-copilot-window.swift](sample_codes/macos-accessibility/find-copilot-window.swift) — lists on-screen Copilot windows with their window and process IDs
- [map-app.sh](sample_codes/macos-accessibility/map-app.sh) — version-stamped UI map for grounding steps and diffing app updates
- [capture-copilot-window.sh](sample_codes/macos-accessibility/capture-copilot-window.sh) — older Accessibility-rectangle fallback

### Drive App Work Without GUI Scripting

Prefer session orchestration:

- `list_projects` to find a project id.
- `create_session` to create a new isolated session.
- `send_session_message` to give that session work.
- `get_session` to inspect path and metadata.
- `navigate_to` only when the user explicitly wants to see the session.

See [session-orchestration.md](references/session-orchestration.md).

### Use Canvases for Structured Human-Agent Work

For test boards, dashboards, course trackers, or visible state, use canvas surfaces instead of GUI clicking. Canvases are bidirectional and can expose agent-callable actions. See [canvas-and-automation.md](references/canvas-and-automation.md).

## Decision Table

| Goal | Best mechanism |
|---|---|
| Learn how sessions behave | Create separate sessions and compare outputs |
| Type/clear a prompt in the desktop UI | macOS Accessibility `Message` text area |
| Click a named app button | Accessibility by role/name/action |
| Capture a course screenshot | Accessibility window bounds + `screencapture` PNG + WebP conversion |
| Launch recurring experiments | App automations/workflows |
| Build a visible experiment dashboard | Canvas extension |
| Steer a CLI session away from machine | Copilot CLI remote control |
| Test PR/issue lifecycle | App session APIs plus GitHub issue/PR tools |
| Full native UI regression testing | Appium Mac2 after explicit setup |

## Source References

- GitHub Copilot app overview: <https://docs.github.com/en/copilot/concepts/agents/github-copilot-app>
- Agent sessions: <https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions>
- Canvas extensions: <https://docs.github.com/en/copilot/how-tos/github-copilot-app/working-with-canvas-extensions>
- Automations: <https://docs.github.com/en/copilot/how-tos/github-copilot-app/using-automations>
- Copilot CLI remote control: <https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-remote-control>
- Apple UI scripting: <https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/AutomatetheUserInterface.html>
