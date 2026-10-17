# GitHub Copilot app workshop: facilitator guide

## Workshop at a glance

**Audience:** beginners who have GitHub accounts and Copilot access
**Duration:** 90 minutes, plus a separate 20-minute participant preflight call
**Working artifact:** the existing `samples/book-app-web` React app
**Presentation:** [copilot-app-book-app-workshop.pptx](./copilot-app-book-app-workshop.pptx)
**Learner outcome:** plan, build, review, and verify a small coding task in the Copilot app; explain how a custom agent differs from a skill; create and test a focused agent with role-appropriate tools; and observe an instructor-led WorkIQ MCP demonstration.

The lesson is about supervising work in the app, not about building a production application from scratch. Keep the feature small and use the canonical Book App in this course repository.

## Before inviting learners

1. Ensure `.github/agents/book-app-reviewer.agent.md` and `.github/skills/book-app-reviewer/SKILL.md` are committed to this repository's default branch before learners open their projects.
2. The repository is public, so learners can clone it with read access. Forking is not required; grant Write access only if learners should push their own branches.
3. Keep `main` protected and have each learner work from their own checkout in a separate session/worktree and branch. Never ask the whole class to edit or push directly to `main`.
4. Confirm the GitHub Copilot app is available to learners and permitted by organization policy.
5. Run the sample's tests and build, then open its browser preview. Do not begin class with an unverified starting point.
6. Confirm the facilitator's WorkIQ MCP connection is available and choose a safe, authorized example that can be demonstrated without exposing private information. Participants do not need WorkIQ access.
7. Open the slide deck and keep this guide available. Present slides 1–5 during the Wednesday preflight call; use slides 6–27 during the workshop.
8. If custom agents are unavailable in the app version learners use, demonstrate the prepared reviewer and have participants draft their agent definition for a follow-up; protect implementation and verification time.

## Wednesday preflight call (20 minutes)

Use slides 3–5. The goal is to resolve setup blockers before the live lesson.

| Time | Facilitator action |
| --- | --- |
| 0–3 min | Explain that learners will open their own checkout of this public repo as an app project, change the Book App on a separate branch/worktree, and verify the result. They do not need to fork or use GitHub CLI. |
| 3–8 min | Ask everyone to install and sign in to the GitHub Copilot app. Confirm Copilot access and any organization restrictions. |
| 8–13 min | Confirm every learner can clone/open this repo as a project in the app. Have them create a separate session/worktree from `main`; do not have learners share a working directory or edit `main`. |
| 13–18 min | Confirm Git is available (`git --version`) and Node.js LTS/npm are installed (`node --version`, `npm --version`). In `samples/book-app-web`, install dependencies and run the tests/build. |
| 18–20 min | Ask learners to open the app's Browser preview. Note any setup blockers and arrange help before class. |

### Prerequisite checklist and commands

- GitHub account with Copilot access; organization policy permits the app and access to this repository.
- Git available to the app for repository/worktree operations. Learners usually do not need to install it separately if it is already present.
- Node.js LTS and npm for the app's local preview and validation. The sample supports Node `^20.19.0 || >=22.12.0`; CI uses Node 22. Use Node 22 LTS for a consistent class environment.
- This repository added as a project in the Copilot app; no fork is required.
- A separate local session/worktree for each learner. Learners need Write permission only if they are expected to push their branches; otherwise local work and verification do not require it.
- GitHub CLI is **not** needed.

From the repository root, run in the app's terminal:

```bash
cd samples/book-app-web
npm ci
npm test -- --run
npm run build
npm run dev -- --host 127.0.0.1 --port 5173
```

Confirm the preview at `http://127.0.0.1:5173`. If `npm ci` fails because the lockfile is absent or out of sync, use `npm install` and report the setup issue; don't keep learners blocked on the preflight call.

## Scope and acceptance criteria

The Book App lets a reader search books by title/author, filter by genre and reading status, and see stats for the visible results. Learners add **Clear filters**:

- The control appears only when a search, genre, or reading-status filter is active.
- Selecting it resets all three filters to their defaults.
- The full list and stats for the full list return.
- Existing search, filtering, stats, accessibility, and empty-state behavior remain intact.
- A search value made only of spaces is not an effective filter and should not show the control.
- For the Book App feature, keep the change small: no new dependencies, backend, database, external API, or unrelated redesign. The separate WorkIQ MCP demonstration does not add an integration to the sample. Do not merge or push.

## 90-minute facilitator run of show

| Time | Slides | What to do |
| --- | --- | --- |
| 0–6 | 6–10 | Orient participants: distinguish GitHub, Copilot, and the Copilot app. Set the goal as coordinating and verifying work, not simply receiving generated code. Introduce the Describe → Plan → Build → Prove loop. |
| 6–15 | 11–13 | Launch the Book App preview. Demonstrate title/author search, genre/status filters, changing stats, and an empty result. Introduce Clear filters and agree what observable success means. |
| 15–25 | 14–16 | Instructor demo: show project/session context, an isolated worktree, Plan mode, and review of the proposal against acceptance criteria before edits are authorized. |
| 25–45 | 16 | Learners create a worktree from `main`, request a plan, check it against the criteria, approve/revise it, and implement Clear filters. Coach them to inspect the changes. |
| 45–68 | 17–20 | Show the prepared Book App Reviewer agent reviewing the implementation and surfacing the whitespace-only search edge case. Explain that an agent is a configured role, instructions, and selected tools—not a new model. Walk through the role menu, then participants choose a role, create an agent with only the tools it needs, and test it against the current Clear filters change. |
| 68–74 | 21 | Instructor-only WorkIQ MCP demonstration. Show one safe, authorized tool call using the preconfigured WorkIQ server. Explain how MCP connects an agent to external tools/data; participants observe only. |
| 74–85 | 22–25 | Learners track actual evidence in Canvas, inspect the app diff and custom-agent output, run tests/build, and verify key filter states in Browser. Distinguish observed results from checks not run. |
| 85–90 | 26–27 | Debrief the plan/build/review/refine/verify loop. Invite each learner to name one useful Copilot app capability and choose an experiment for the next three days. Do not merge or push. |

**Timing check:** 6 + 9 + 10 + 20 + 23 + 6 + 11 + 5 = 90 minutes. Protect the custom-agent activity and verification blocks; keep demonstrations focused.

### WorkIQ MCP demonstration

- Confirm the WorkIQ MCP server is installed and available to the facilitator's Copilot app session before class.
- Prepare one short, safe prompt in advance. Use only information the facilitator is authorized to show; avoid private messages, personal data, confidential content, and live attendee data.
- Make the tool invocation visible if possible. Point out the external tool call, the returned context, and how it differs from repository access.
- Tell participants that MCP is an integration mechanism, not a guarantee of correctness. They should judge tool output and verify any resulting code independently.
- This is a facilitator demonstration only. Do not ask participants to install, authenticate, or query WorkIQ.
- If WorkIQ is unavailable during class, explain the concept with the slide and continue; do not spend the hands-on time debugging the connection.

### Three-day experimentation invitation

Close by inviting learners to use the following three days to explore the app and course repository at their own pace. Suggest trying a new prompt, making a second isolated session, using the reviewer skill/agent, or inspecting how an available MCP server expands an agent's context. Make clear that they should keep experiments in their own worktree and should not push or merge unless separately instructed.

## Learner prompts

### Session A: plan, then build

```text
Add a small Clear filters control to the Book App in samples/book-app-web.

Acceptance criteria:
- Show it only when search, genre, or reading status is not at its default.
- Selecting it resets search, genre, and reading status.
- The full book list and its reading stats return.
- Preserve existing behavior and accessible labels.
- Make no unrelated changes and add no dependencies.

First, inspect the relevant code and propose a short implementation and validation plan. Do not edit files until I approve the plan.
```

After reviewing the plan, approve it only if it covers all three filters and the tests/behavior to check. Then ask the agent to implement the approved plan. If it skipped a case, request a plan revision rather than repairing the feature yourself.

### Hands-on 2: create and test a custom agent

Explain: “An agent is Copilot configured for a particular kind of work. Its name, instructions, and selected tools give it a focused role; it is not a separately trained model. Our Book App Reviewer is read-only, so it can inspect and report, but it cannot edit the app. Other agents can help design tests, investigate bugs, explain code, improve accessibility, build a small feature, or draft documentation.”

Show `.github/agents/book-app-reviewer.agent.md` and point out its frontmatter (`name`, `description`, and `tools`) and its role/boundary instructions. Explain that tool selection sets what an agent is equipped to do; instructions define the task. Read/search tools suit reviewing, investigating, and explaining. Writing tests, changing code, or drafting docs requires edit access, which lets the agent edit files in its workspace, so grant it only when needed and review every change. A narrow prompt is useful guidance, not a technical file-level permission boundary.

Let participants choose a role from slide 18: code reviewer, test designer, bug investigator, accessibility helper, code explainer, feature builder, or documentation helper. Have them create the role in their own worktree.

**Agent-creation prompt** (replace `[ROLE]` with the selected role):
```text
Read `.github/agents/book-app-reviewer.agent.md` as an example. Create a custom agent for this role: [ROLE]. Focus it on the Book App's Clear filters change in `samples/book-app-web`. Choose a clear name and create a separate agent file under `.github/agents/`; do not modify the existing Book App Reviewer.

Give it the least tool access needed for the role. For a read-only role, allow only file-reading and search tools. If its role writes tests, code, or documentation, grant edit access only if needed and clearly instruct it to limit changes to the relevant files. Do not grant terminal, commit, or push tools. State its task, boundaries, and what it must report; require file paths and specific evidence, beginner-friendly explanations, and clear disclosure of checks it did not run. Show me the new agent definition and explain its role, tools, and limits. Do not run it yet.
```

After reviewing the generated definition, reload/reopen the Copilot app if the new agent does not appear. Keep the participant in the same project/worktree where Clear filters was implemented. Select the new agent and use this role-neutral test prompt, replacing `[ROLE]`:

```text
Act as my [ROLE] agent for the Clear filters change in this worktree. Do the job described in your agent instructions, using the smallest useful scope. Do not commit or push. If your role is read-only, report code evidence and checks that still need to be run. If your role makes changes, summarize every file changed and why; do not claim tests, build, or browser checks passed unless you actually ran them.
```

Ask participants to inspect the result: did the agent do the selected job, stay within its intended scope, and support claims with evidence? If it edited files, inspect the diff and decide which tests or browser checks should follow. The agent file and any changes stay in the participant's own worktree; do not push or merge during the exercise.

## Canvas activity

Create or open a simple workshop board in the app's Canvas side panel. Use four items:

1. **Feature proposal** — acceptance criteria, status: ready.
2. **Build session** — plan approval and implementation status.
3. **Custom agent work** — selected role, output or changes, and what needs human verification.
4. **Verification evidence** — diff inspected, tests, build, browser checks; status reflects what actually ran.

Keep the board small and visible. Explain that it summarizes task state; it does not prove that the code or agent review is correct.

## Verification checklist

From Session A's `samples/book-app-web` directory:

```bash
npm test -- --run
npm run build
```

In the Browser preview, check each of the following:

1. With no active filters, Clear filters is absent and the complete list/stats are shown.
2. Enter a search term; Clear filters appears.
3. Select a genre; Clear filters appears.
4. Select a reading status; Clear filters appears.
5. With more than one filter active, selecting Clear filters resets all three, restores the full list, and updates stats.
6. Enter spaces only in the search box; Clear filters stays hidden because the search is not effective.
7. Review the diff for scope and accessible control text. Confirm the existing empty-state and filter behavior remain intact.
8. Compare the custom agent's output or changes with the task. Include the reviewer-discovered whitespace-only search edge case in verification; an agent report is not proof of runtime behavior.

If tests, build, or preview do not run, record them as **not run/blocked**, not as passed. Use the Canvas to make the distinction visible.

## Facilitation and recovery

- **Git/worktree setup fails:** keep learners in their current project session and have them observe the instructor demo; do not switch branches or use shared files to simulate isolation.
- **New custom agent does not appear:** confirm its definition is saved under `.github/agents/` in the learner's worktree, then reload/reopen the Copilot app. If time runs out, have the learner inspect the definition and let the facilitator demonstrate a prepared agent; finish testing the learner's agent after class.
- **Skill is not offered automatically:** explicitly mention/use the `book-app-reviewer` skill in the prompt. A skill provides reusable task instructions; it does not itself enforce a read-only permission boundary.
- **Canvas unavailable:** make a four-row status board in a plain-text note or on a shared whiteboard, and continue the exercise. Do not claim that this fallback is the Copilot Canvas.
- **Implementation takes longer:** preserve time for one test/browser verification and a short custom-agent test. The agent-creation activity can continue after class; do not claim an untested agent worked.
- **A learner's feature does not work:** ask them to reproduce one acceptance criterion, inspect the exact diff, and revise the prompt/plan. The lesson is about the work loop, not racing to a perfect demo.

## Materials in this repository

- `samples/book-app-web`: working, beginner-sized frontend artifact.
- `.github/skills/book-app-reviewer/SKILL.md`: reusable review guidance.
- `.github/agents/book-app-reviewer.agent.md`: prepared read-only reviewer role for the parallel session.
