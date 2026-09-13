# Session Orchestration

## Use This Before GUI Automation

When the goal is to learn or test Copilot App behavior, create and drive isolated sessions through app/session APIs instead of clicking the native UI.

## Safe Session Experiment Flow

1. List projects and choose the target project.
2. Create a separate session with a descriptive name.
3. Keep it idle if doing GUI composer tests.
4. Use `send_session_message` only when the user wants the agent to actually work.
5. Inspect the session with `get_session`.
6. Navigate to the session only when the user explicitly wants the App UI to change.

## Hidden Session Requirements

When the user asks for a hidden or separate instance:

- Use `create_session` with `coordinate_with_creator: false` and a kickoff prompt when possible.
- Use `send_session_message` for follow-up work.
- Do not call `navigate_to`; it switches the user's visible App window.
- Do not use foreground `open -a`, menu commands, folder picker dialogs, or Accessibility clicks.
- If a local folder is not already a project, make it a distinct repo root first so the App does not resolve a parent repository.
- If a non-interactive project registration path is unavailable, stop and report that limitation rather than making the user select a folder.
- Hidden sessions can be verified with `get_session`, filesystem checks in the session path, and session event metadata.

## Example Prompt Strategy

Use prompts that clearly identify test intent:

```text
This is a controlled Copilot App automation experiment. Do not edit files. Tell me the session mode you appear to be running in and what project context is available.
```

For destructive workflows, create a disposable project/session first.

## What to Observe

- Session name and id.
- Project id and repo/folder path.
- Whether a worktree was created.
- Mode behavior: Interactive vs Plan vs Autopilot.
- Whether the app exposes diffs, timeline events, terminal outputs, and composer controls.
- Whether the session can be messaged from another session.
- Whether the session remained hidden: no `navigate_to`, no foreground `open`, no menu/picker interaction.

## Cleanup

- Do not delete sessions unless the user explicitly asks.
- Do not remove worktrees or folders unless ownership is clear and the user approves.
- Record observations in session artifacts unless the user asks for repo docs.
