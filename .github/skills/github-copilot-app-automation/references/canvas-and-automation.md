# Canvases and Automations

## Canvases

Use canvases when chat is not enough and both the user and agent need a shared work surface.

Good Copilot App automation canvas ideas:

- Course research board.
- Session experiment dashboard.
- Issue triage board.
- PR review checklist.
- App UI affordance map.
- Accessibility-control inventory.

Canvas prompt pattern:

```text
/create-canvas Create a GitHub Copilot app automation research board with cards for sources, app controls, experiments, risks, and course ideas. Add actions to add a card, move a card, mark a source verified, record an experiment result, and export the board to markdown.
```

## Automations

Use automations for recurring agent tasks, not for low-level GUI control.

Good automation ideas:

- Daily summarize open PRs.
- Weekly review stale issues.
- On-demand run a course repository health check.
- Scheduled prompt to collect app behavior notes.

Safety:

- Select least-privilege tools.
- Avoid prompts that include secrets.
- Prefer manual/on-demand first.
- Cloud automations can have policy, visibility, and billing implications.
