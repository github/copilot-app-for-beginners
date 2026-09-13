# Book App Web PR Scenarios

Use these drafts to create repeatable pull request exercises for the course.

## PR scenario 1: Review comment asks for clearer empty-state copy

Branch: `fix-empty-state-copy`

### PR summary

This PR updates the empty state shown when filters match no books.

### Seeded PR conversation comment

The copy is better, but can we make it more helpful for a first-time learner? Please mention that they can change the search term, genre, or reading status.

### Learner goal

Ask Copilot to address the PR conversation comment, inspect the diff, and decide whether to accept the change.

## PR scenario 2: Failing CI points to the stats test

Branch: `practice-failing-stats-check`

### PR summary

This PR intentionally changes the stats logic so CI can demonstrate a failing check.

### Seeded CI failure

`npm test -- --run` fails in `src/tests/stats.test.tsx` because the favorite count excludes unread favorites.

The repository includes `.github/workflows/book-app-web.yml`, which installs dependencies with `npm ci`, runs the tests, and builds `samples/book-app-web`. Use this workflow for the failing-check lesson after creating the intentional regression branch.

### Learner goal

Use the failing check as context, ask Copilot for a root cause, and fix the stats logic without changing the test expectation.

## PR scenario 3: Agent Merge waits on checks and review state

Branch: `feature-reading-dashboard`

### PR summary

This PR adds a safe training note used for merge-readiness discussion after tests pass and comments are resolved.

### Merge readiness checklist

- Tests pass with `npm test -- --run`.
- The app builds with `npm run build`.
- The `Book app web` workflow passes in GitHub Actions.
- Review comments are resolved.
- The learner confirms the branch is safe for a training repository.

### Learner goal

Discuss when Agent Merge is appropriate, what it waits for, and why a human should still review the final diff.
