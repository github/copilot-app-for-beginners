# GitHub Copilot app Automation Map

## Surfaces Available to Agents

### Session and Project APIs

Use these before GUI automation when available:

| Tool family | What it enables |
|---|---|
| `list_projects` | Discover project ids, repo names, default branches, local paths |
| `list_sessions_and_chats` | See active and historical app sessions/chats |
| `get_session` | Inspect a session's path, project, branch/worktree metadata |
| `create_session` | Create an isolated local or cloud app session |
| `send_session_message` | Drive another session with a prompt |
| `navigate_to` | Switch the visible app UI to a session |
| `open_issue_session` / `open_pr_session` | Create or open issue/PR-specific sessions |
| `create_pull_request`, `update_pull_request` | Work with PR lifecycle from the app environment |
| `add_pr_review_comment` | Stage PR review comments where available |

### Canvas APIs

Use canvases when the task needs visible structured state:

- Open/focus a canvas.
- Invoke canvas actions.
- Use editor/browser/terminal/document canvases where available.
- Create custom canvas extensions for project boards, research dashboards, triage boards, release checklists, and task launchers.

### Workflow APIs

Use workflows for repeatable experiments:

- `list_workflows`
- `save_workflow`
- `run_workflow`

Observed state during research: no saved workflows existed.

### macOS Accessibility

Use Accessibility when the visible app UI must be exercised:

- Process: `GitHub Copilot`
- Window: `GitHub Copilot`
- Main content: `AXWebArea` described as `GitHub Copilot`
- Composer: `AXTextArea name=Message`
- Model picker: `AXComboBox name=Select model`

## Recommended Automation Ladder

1. **Use app/session APIs** for reliable orchestration.
2. **Use canvases** for visible shared state and agent-callable capabilities.
3. **Use workflows/automations** for repeatable tasks.
4. **Use Accessibility** only for GUI-specific behavior.
5. **Use Appium Mac2** only if Accessibility scripts need to become durable regression tests.

## Anti-Patterns

- Do not click by screen coordinates unless explicitly approved.
- Do not submit prompts or destructive actions from Accessibility scripts without explicit user approval.
- Do not assume the app is Electron.
- Do not assume windows stay exposed; always rediscover process/window/web area.
- Do not automate broad UI scraping of private content into repo files.
