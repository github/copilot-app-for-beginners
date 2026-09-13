# Training GitHub Scenarios

The root README and Chapter 00 include the normal fork, clone, and setup-script path. This appendix explains what [the setup script](../.github/scripts/setup-training-scenarios.js) creates and gives manual fallback steps for learners who cannot run it.

Use a fork or disposable training repository. Do not use a production repository.

## What you'll create

| Course item | Details | Used in |
|---|---|---|
| Nine labels and five issues | [Course issue drafts](../samples/app-course-issues.md) | Chapters 02, 03 |
| Seven practice branches | [Branch names and changes](#manual-fallback-create-practice-branches) | Chapters 02, 03 |
| Three pull requests and one conversation comment | [Pull request setup](#manual-fallback-create-pull-request-scenarios) | Chapters 03, 07 |
| One failing-check PR | [Failing-check example](#manual-fallback-create-a-failing-check-example) | Chapters 03, 07 |

## Prerequisites

- A GitHub account with permission to create labels and issues, push branches, and open pull requests in the training repository
- A fork of this course repository, or another disposable training copy pushed to GitHub
- GitHub Issues enabled under the repository's **Settings** > **Features** for the manual path. The script enables Issues if needed.
- GitHub Actions enabled for the repository. Open its **Actions** tab and enable workflows if GitHub shows a prompt. The script requires the **Book app web** workflow to be active.
- Git and Node.js LTS available in your terminal, with the cloned fork's root folder as the working directory
- A clean working tree with no uncommitted changes before running the script or creating a practice branch
- For the script path, GitHub CLI (`gh`) signed in to the account you used to create the fork. The manual steps use GitHub.com instead of `gh`.

If you cannot create issues or pull requests, read the workflows and follow along with the screenshots instead.

## Recommended path: Fork, clone, run the setup script

1. Follow [Chapter 00](../00-setup/README.md#connect-to-your-repository) to fork and connect the repository, open a **Local repository** session, and check your tools and GitHub CLI sign-in in the **Terminal** tab.
2. From the root folder of your cloned fork, preview what the setup script will do:

   ```bash
   node .github/scripts/setup-training-scenarios.js --dry-run
   ```

3. Confirm that the `Repository:` line shows your fork, then run the setup:

   ```bash
   node .github/scripts/setup-training-scenarios.js --yes
   ```

4. Complete the [readiness check](#quick-readiness-check) below.

The script targets the repository configured as the local `origin` remote. It stops before making changes to the upstream course repository or a repository owned by someone other than the signed-in user. For an authorized organization fork, add `--allow-shared-repository` with `--yes` only after confirming the target.

## What the setup script creates

On a fresh training fork, the script:

- Enables GitHub Issues if needed, then fetches and updates the local default branch.
- Creates the nine labels and five issues listed below. Each new issue is assigned to the GitHub user authenticated with `gh`.
- Creates and pushes seven practice branches from the remote default branch. Five change app behavior; two add README notes only.
- Opens three pull requests against the default branch. One intentionally fails the **Book app web** check.
- Adds one conversation comment to **Improve empty-state copy**. This is a comment in the PR conversation, not an inline review thread.
- Returns to the branch that was active when setup started.

The script reuses existing issues by title, branches by name, pull requests by their source branch, and the matching conversation comment. It updates existing course label colors and descriptions. It does not reset changed practice branches, reopen closed issues or PRs, or restore a failing check that you already fixed.

## Manual fallback: Create the labels

To reproduce the full course setup without the script, complete all the manual sections below. Work in your fork, not the upstream course repository.

In your fork on GitHub.com, open **Issues** > **Labels**. Create any missing labels with these names, colors, and descriptions. For existing labels, update their colors and descriptions to match:

| Label | Color | Description |
|---|---|---|
| `book-app-web` | `#1f883d` | Course sample app scenario |
| `good first issue` | `#7057ff` | Beginner-friendly course issue |
| `bug` | `#d73a4a` | Intentional course bug scenario |
| `tests` | `#0052cc` | Testing or CI scenario |
| `accessibility` | `#0e8a16` | Accessibility-focused scenario |
| `copy` | `#5319e7` | Content or copy scenario |
| `ui` | `#c2e0c6` | User interface scenario |
| `responsive` | `#bfd4f2` | Responsive layout scenario |
| `ci` | `#fbca04` | Continuous integration scenario |

## Manual fallback: Create the seeded issues

Create these five issues in your fork. Use each linked draft's problem description, reproduction steps, expected result, and learner goal. Include its training branch name from the branch table below. Keep the training code changes in the branch, not in the default app.

| Issue title and draft | Labels |
|---|---|
| [Make search case-insensitive](../samples/app-course-issues.md#issue-1-make-search-case-insensitive) | `bug`, `good first issue`, `book-app-web` |
| [Keep unread stats correct when filters are active](../samples/app-course-issues.md#issue-2-keep-unread-stats-correct-when-filters-are-active) | `bug`, `tests`, `book-app-web` |
| [Improve the empty state copy](../samples/app-course-issues.md#issue-3-improve-the-empty-state-copy) | `accessibility`, `copy`, `book-app-web` |
| [Polish book card spacing and responsive layout](../samples/app-course-issues.md#issue-4-polish-book-card-spacing-and-responsive-layout) | `ui`, `responsive`, `book-app-web` |
| [Simulate a failing stats test for CI practice](../samples/app-course-issues.md#issue-5-simulate-a-failing-stats-test-for-ci-practice) | `ci`, `tests`, `book-app-web` |

Assign each issue to yourself so it is easier to find in **My work**. Issue and PR numbers can vary. Match items by title rather than by a fixed number.

## Manual fallback: Create practice branches

Create all seven branches below. Start each new branch from the same unchanged default branch, not from another practice branch.

The commands below assume the default branch is `main`. If your fork uses a different name, substitute that name. Before starting, run these commands from the repository root:

```bash
git status
git remote -v
```

Confirm that there are no uncommitted changes and that `origin` points to your fork. Then update the default branch:

```bash
git fetch origin main
git switch main
git pull --ff-only origin main
```

| Branch | Change to make |
|---|---|
| `practice-search-case-bug` | Apply the case-sensitive search change in [Issue 1](../samples/app-course-issues.md#issue-1-make-search-case-insensitive). |
| `practice-unread-count-bug` | Pass all books instead of filtered books to `ReadingStats`, as shown in [Issue 2](../samples/app-course-issues.md#issue-2-keep-unread-stats-correct-when-filters-are-active). |
| `practice-empty-state-copy` | Use **No results** and **Try again.**, as shown in [Issue 3](../samples/app-course-issues.md#issue-3-improve-the-empty-state-copy). |
| `practice-card-polish` | Add the **Visual polish practice** README note below. Do not change the app behavior. |
| `practice-failing-stats-check` | Count only read favorites, as shown in [Issue 5](../samples/app-course-issues.md#issue-5-simulate-a-failing-stats-test-for-ci-practice). |
| `fix-empty-state-copy` | Use the empty-state JSX below. This is separate from `practice-empty-state-copy`. |
| `feature-reading-dashboard` | Add the **Training scenario note** below. Do not add a dashboard feature. |

For example, create the first branch from `origin/main`:

```bash
git switch -c practice-search-case-bug origin/main
```

Apply only that branch's change from the table. Commit and push it, then return to `main`:

```bash
git add samples/book-app-web
git commit -m "Seed search case practice bug"
git push -u origin practice-search-case-bug
git switch main
```

Repeat this pattern for the other six branches, replacing the branch name and commit message. Always create the next branch from `origin/main`. If a branch already exists, inspect and reuse it rather than overwriting it.

For `fix-empty-state-copy`, replace the empty-state heading and paragraph in `samples/book-app-web/src/App.tsx` with:

```tsx
<h2>No books found</h2>
<p>Adjust your filters and try again.</p>
```

For `practice-card-polish`, append this text to `samples/book-app-web/README.md`:

```markdown
## Visual polish practice

Use this branch to practice planning responsive card improvements before changing UI code.
```

For `feature-reading-dashboard`, append this text to `samples/book-app-web/README.md`:

```markdown
## Training scenario note

This branch is used for the Agent Merge readiness discussion in the course. It keeps the app behavior stable while giving learners a safe pull request to inspect.
```

## Manual fallback: Create pull request scenarios

On GitHub.com, open three pull requests using the branches you already pushed. Set the base branch to `main`, or your fork's default branch. Use these exact titles and the linked scenario summaries:

| PR title | Source branch | Scenario |
|---|---|---|
| Improve empty-state copy | `fix-empty-state-copy` | [PR scenario 1](../samples/app-course-pr-scenarios.md#pr-scenario-1-review-comment-asks-for-clearer-empty-state-copy) |
| Failing stats check practice | `practice-failing-stats-check` | [PR scenario 2](../samples/app-course-pr-scenarios.md#pr-scenario-2-failing-ci-points-to-the-stats-test) |
| Reading dashboard merge-readiness practice | `feature-reading-dashboard` | [PR scenario 3](../samples/app-course-pr-scenarios.md#pr-scenario-3-agent-merge-waits-on-checks-and-review-state) |

On **Improve empty-state copy**, add this comment in the PR's **Conversation** tab:

> The copy is better, but can we make it more helpful for a first-time learner? Please mention that they can change the search term, genre, or reading status.

This matches the script's conversation comment. Do not create an inline review thread for this setup. Leave all three PRs open for the course exercises.

## Manual fallback: Create a failing check example

The repository includes the [Book app web workflow](../.github/workflows/book-app-web.yml). It uses Node.js 22, installs dependencies with `npm ci`, runs `npm test -- --run`, and builds `samples/book-app-web` with `npm run build`.

The **Failing stats check practice** PR created above is the failing-check example. Do not create a second branch or PR for it.

1. Open that PR and wait for the **Book app web** check to finish.
2. Confirm that it fails in `src/tests/stats.test.tsx` because the favorite count excludes unread favorites.
3. Leave the intentional failure in place for Chapter 03. Do not weaken the test or fix the branch during setup.

On a fresh training fork, the other two seeded PRs should pass. If no check starts, confirm that workflows are enabled in the fork's **Actions** tab.

## Keep the training repo safe

- Use a fork or disposable training repository.
- Keep one regression per branch.
- Do not merge intentional regression branches into the default branch.
- Do not add secrets, production data, or private customer data.
- Delete training branches after the course if you no longer need them.

## Quick readiness check

Before starting Chapter 02 on a fresh training fork, confirm:

- [ ] All nine course labels exist.
- [ ] All five issues exist, have the listed labels, and are assigned to you.
- [ ] All seven practice branches are pushed to your fork.
- [ ] All three PRs are open against the default branch.
- [ ] **Improve empty-state copy** has the conversation comment shown above.
- [ ] **Failing stats check practice** has the expected failing **Book app web** check, and the other two PRs pass.
- [ ] You can see your fork's issues and PRs in **My work** in the GitHub Copilot app.

If you already completed an exercise, its PR state or check result may have changed. Rerunning the script does not undo that work.
