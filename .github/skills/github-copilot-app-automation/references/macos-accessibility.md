# macOS Accessibility Automation

## Permission Requirement

macOS Accessibility control must be granted to the automation caller. If `osascript` returns an assistive access error, stop and have the user grant access in System Settings.

Typical error:

```text
System Events got an error: osascript is not allowed assistive access.
```

## Read-Only Probe Pattern

Use read-only probes first:

```bash
COPILOT_PID="$COPILOT_PID" bash sample_codes/macos-accessibility/map-app.sh
osascript sample_codes/macos-accessibility/probe-readonly.applescript "$COPILOT_PID"
```

Expected useful outputs include:

- process names
- window names
- menu bar items
- `AXWebArea` children
- named buttons/groups/text controls

## Control Discovery Notes

The Copilot App shell may look like:

```text
AXWindow GitHub Copilot
  AXGroup
    AXGroup
      AXScrollArea
        AXWebArea GitHub Copilot
```

Known controls:

```text
AXGroup      Sidebar
AXCheckBox   Toggle sidebar
AXPopUpButton Create new project or session
AXButton     New session in <project>
AXTextArea   Message
AXComboBox   Select model
AXGroup      Conversation timeline
AXButton     Open changes
```

## Safe Draft Prompt Test

Use the draft test to confirm write access to the prompt composer without submitting:

```bash
osascript sample_codes/macos-accessibility/type-and-clear-draft.applescript "$COPILOT_PID"
```

Expected shape:

```text
direct-set-worked=true
typed-value=DRAFT ONLY - accessibility automation probe - do not submit
cleared-value=
```

## Dedicated Persona Launch

For screenshot work, do not use `open -a`, which can select an existing app
instance. Launch a new process from the persistent, signed-in persona and
verify the exact repository:

```bash
SK=.github/skills/github-copilot-app-automation/sample_codes/macos-accessibility
PERSONA="demo"
COPILOT_PID="$(bash "$SK/prepare-persona.sh" \
  "$PERSONA" "$HOME/Desktop/projects/copilot-app-for-beginners" 60)"
```

Use the returned process ID for subsequent Accessibility operations and pass it
to the supplied AppleScript probes and `capture-window.sh`. App/session APIs
belong to the Copilot instance that hosts the agent and can navigate the wrong
window. After the persona starts, drive the screenshot instance through
Accessibility selectors scoped to its process ID.

`prepare-persona.sh` requires an existing signed-in persona. It verifies the
repository and, when needed, opens the native folder picker and supplies the
exact path. It does not succeed until the repository name appears in the
selected process. After a verified capture, run `cleanup-persona.sh` with the
same persona name and process ID. Cleanup preserves the persona and login.

## Screenshot Identity Sanitization

A process-specific `capture-window.sh` run automatically:

- Reads the profile control from the selected process.
- Derives the person's display name instead of using a name list.
- Derives matching account handles and personal repository owners by normalized
  comparison.
- Replaces profile text with `Copilot Dev`.
- Replaces matching account handles and repository owners with `copilotdev`.
- Keeps the avatar and unrelated people and organizations unchanged.
- Verifies with OCR that the source identity text is absent.
- Adds ordered red number callouts when repeated
  `--callout NUMBER:X:Y` arguments are supplied.

This step requires `tesseract` and Pillow. If identity detection succeeds but
OCR cannot find or remove the text, capture fails and keeps the `.raw.png` file
for manual review.

## Robustness Requirements

- For screenshot work, run `launch-persona.sh` and target its returned process
  ID instead of opening or selecting an arbitrary instance.
- Add short delays after focusing the app.
- Re-find the `AXWebArea` and `Message` text area before every operation.
- Prefer setting `value` directly over simulated typing when possible.
- If direct set fails, fall back to `keystroke` only after focusing the text area.
- Clear drafts with Command+A then Delete.
- Never send Return/Enter unless the user explicitly asked to submit.
