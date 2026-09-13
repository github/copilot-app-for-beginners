# GitHub Copilot app UI Map

- app_version: 1.1.20
- captured: 2026-09-13 (macOS, New screen)
- privacy: project names, session names, pull request titles, and the account name
  are redacted to `<placeholder>`. Regenerate with
  [map-app.sh](../sample_codes/macos-accessibility/map-app.sh) from a sanitized
  account, then re-redact before committing.

A factual reference for grounding course steps and screenshots in the app's real
UI. Menus are always mappable; window controls below were captured with the New
screen visible on the active Space. Re-run `map-app.sh` after an app update and
diff against this file.

## Menus

- **GitHub Copilot**: About GitHub Copilot · Settings… · Check for Updates… · Services · Hide… · Quit
- **File**: New Session · New Session Without Project · New Session from Recent · Open URL From Clipboard · Create from Local Folder or Repository · Create from GitHub · Create from URL · Close Window
- **Edit**: Undo · Redo · Cut · Copy · Paste · Select All · Writing Tools · AutoFill · Start Dictation… · Emoji & Symbols
- **View**: Toggle Sidebar · Toggle Review Panel · Toggle Terminal · Command Palette · Back · Forward · Actual Size · Zoom In · Zoom Out · Enter Full Screen
- **Window**: New Window · Minimize · Zoom · Bring All to Front
- **Help**: Documentation · Keyboard Shortcuts · What's New · Manage Copilot Subscription · Automations · MCP Servers · Skills · Share Feedback · Run Health Check · Show Home Tips Again · Credits

## Sidebar (navigation)

- Toggle sidebar (checkbox) · Go back · Go forward · Resize sidebar
- **Quick links**: New · My work · Automations · Customize
- **Projects**: Configure sessions · New project or session
  - Chats (+ New chat)
  - One row per connected project: `<project-name>`, each with
    "Create project from pull requests, branches, or issues in `<project-name>`"
    and "New session in `<project-name>`"
- **User profile and settings** (bottom): "Open user menu for `<user>`" · Share feedback · Settings

## Session composer (New)

- AXTextArea **Message** — placeholder: "Ask anything or paste a URL. Use / for commands, & sessions, # issues…"
- AXPopUpButton **Add context**
- AXPopUpButton **Mode: Interactive** (session mode selector)
- AXPopUpButton **Model and reasoning** (e.g., "GPT-5.6 Sol · Medium")
- AXPopUpButton **Set up voice dictation**
- AXComboBox **Chat** or the selected project name

## New content

- Composer for a chat or selected project
- Project picker: Chat · connected projects · Add GitHub repository · Clone repository · Open folder
- Sample project or prompt idea cards vary by selected project state
- Footer: "GitHub Copilot uses AI. Check for mistakes."

## Settings dialog

- Standard categories: General · Accounts · Sessions · Themes · Accessibility ·
  Voice dictation · Customize · Model providers · Experimental
- The General category can show the current app version. Remove that version
  from course screenshots because it changes frequently.

## Window chrome

- Close · Minimize · Enter Full Screen · Notifications

## Notes for the course

- Enable and verify Streamer Mode before mapping or capturing. It hides
  unreleased features that the public cannot access.
- The composer exposes Mode and the combined model and reasoning control directly
  (grounds Chapter 01's model/reasoning guidance).
- The File menu's "Create from Local Folder or Repository / GitHub / URL" matches
  Chapter 00's connect-the-repository options.
- "New", "My work", "Automations", and "Customize" are top-level Quick links
  when Streamer Mode is enabled.
- "Chats" and connected repositories appear under "Projects".
