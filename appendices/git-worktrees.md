# Git Worktrees

Git worktrees are one of the most important ideas in the GitHub Copilot app. They let the app run more than one coding session without mixing all changes into the same folder.

## Plain-English definition

A git worktree is another working folder that is connected to the same repository.

Think of your repository like a shared source library. A worktree is a separate desk where you can check out a different branch and work without disturbing the main desk.

In the GitHub Copilot app, a session often gets its own branch and worktree. That means:

- your main checkout can stay clean,
- each session can make changes in its own folder,
- parallel sessions are easier to compare,
- you can inspect a session without accepting its changes.

## Worktree, branch, and session

| Term | Beginner meaning |
|---|---|
| Session | A GitHub Copilot app workspace where an agent plans, edits, tests, and reports progress |
| Branch | A named line of work in git, usually for one feature or fix |
| Worktree | A separate folder attached to the same repo, often checked out to a session branch |

The app may create a branch name such as `copilot/fix-unread-count` and a matching worktree folder. The exact name depends on your app settings and project branch prefix.

## Why the app uses worktrees

Worktrees help keep agent work inspectable and reversible.

For example, one session can fix a search bug while another session writes tests. Each session can have its own folder, branch, terminal, browser preview, and diff. You can review each one before deciding what should become a pull request.

## Safe inspection checklist

Use this checklist when you'd like to look at a session worktree.

1. Find the session in the GitHub Copilot app.
2. Note the branch name and worktree path shown by the app.
3. Open the worktree folder only for inspection or careful editing.
4. Confirm your editor shows the session branch, not your main branch.
5. Avoid deleting, renaming, or moving the worktree while the session is active.
6. Use the app's diff view before accepting changes.
7. Run validation commands from the session worktree, not from the main checkout.

For the sample app, validation usually starts here:

```bash
cd samples/book-app-web
npm install
npm test -- --run
npm run build
```

If you're inside a session worktree, run those commands from that worktree's `samples/book-app-web` folder.

## What not to do

Avoid these actions unless you know exactly why they are safe:

- Do not delete an active worktree from Finder, Explorer, or the terminal.
- Do not rename a worktree folder while the app still tracks it.
- Do not manually switch the branch inside an active session worktree.
- Do not copy unreviewed changes from one worktree into another.
- Do not assume worktrees isolate everything on your computer.

Worktrees isolate files and branches. They do not automatically isolate ports, local databases, Docker containers, cache folders, environment files, or background processes.

## Port and resource conflicts

Two sessions can still collide if they use the same outside resource.

### Example: Web server port conflict

The sample web app uses Vite. The default course command uses port `5173`:

```bash
npm run dev -- --host 127.0.0.1 --port 5173
```

If two worktrees both start the app on port `5173`, the second one may fail or choose a different port. Use a different port for the second session:

```bash
npm run dev -- --host 127.0.0.1 --port 5174
```

Label browser tabs or canvas previews so you know which session you're viewing.

### Example: Shared local files

If two sessions read the same `.env.local`, cache folder, or generated file outside the worktree, they can affect each other. Prefer session-local files and avoid putting secrets in course examples.

### Example: Containers and services

If a chapter later uses containers or local services, give each session a unique service name, container name, database name, or port. Stop unused services before starting another session.

## Cleanup

Prefer cleanup from inside the GitHub Copilot app when possible. The app understands which session owns which worktree.

Before cleanup:

1. Review the session diff.
2. Save anything you need by committing, opening a PR, or copying only reviewed changes.
3. Stop dev servers, terminal tasks, and browser previews tied to that worktree.
4. Close editors that are open in the worktree.
5. Use the app's session cleanup or close action when available.

If a worktree was created outside the app, use normal git commands only after checking the branch and path:

```bash
git worktree list
git worktree remove path/to/worktree
git branch --delete branch-name
```

Use `git branch --delete` only after the work is merged or intentionally discarded. If git refuses to delete the branch, stop and inspect why.

## Troubleshooting

| Symptom | What to check |
|---|---|
| The app cannot find a session folder | The worktree may have been moved or deleted manually |
| Tests pass in one folder but fail in another | Branch, dependency install status, environment variables, and generated files |
| Browser preview shows the wrong change | Browser tab points to the wrong port or session |
| Two sessions edit the same files | Pause one session, compare diffs, and choose the source of truth |
| Cleanup fails | Stop running processes, close editors, and use the app cleanup path first |

Related chapter: [Chapter 02: Sessions, Worktrees, and Context](../02-sessions-worktrees-context/).
