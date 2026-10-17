# Copilot app workshop: participant preparation and facilitator runbook

This document has two parts: setup instructions to send participants before class, and a timed, step-by-step runbook for the 90-minute workshop.

**Workshop project:** [hackathon-purple-bear-26/copilot-app-for-beginners](https://github.com/hackathon-purple-bear-26/copilot-app-for-beginners)  
**Workshop sample:** `samples/book-app-web`  
**Related materials:** [Facilitator guide](./copilot-app-workshop-facilitator-guide.md) · [Slide deck](./copilot-app-book-app-workshop.pptx)

## Part 1: Send to participants before the workshop

### What you need

- A GitHub account with access to GitHub Copilot. If you use a work or school account, your administrator must allow the Copilot app and Copilot for your account.
- The GitHub Copilot app installed and signed in before the workshop.
- Git installed and available to the app.
- Node.js 22 LTS and npm. npm is included with Node.js. The Book App supports Node.js `^20.19.0 || >=22.12.0`; use Node.js 22 for the most consistent workshop setup.
- A reliable internet connection for signing in and cloning the public repository.

GitHub CLI is not required. You do not need to fork the repository or have write access for this workshop. The repository is public; participants need read access to clone it. Workshop work stays in each participant's own local session/worktree, and nobody needs to push or merge changes.

### Add the workshop repository to the Copilot app

1. Open the GitHub Copilot app and sign in with the account that has Copilot access.
2. Add the workshop repository as a project. In the app, use the add-project control beside **Projects**, choose the GitHub repository option, and select `hackathon-purple-bear-26/copilot-app-for-beginners`. Authenticate if the app prompts you.
3. If you have already cloned the repository, add/open its local folder as a project instead.
4. Do not work in a shared folder with another participant. During class, create your own session/worktree from the repository's default branch (`main`).

You do not need to fork the repo. The dependable route is to add or clone the repository from inside the Copilot app; the GitHub website does not need to provide a separate “Open with app” button.

### Check the sample before class

Open the repository project in the app. In its terminal, run:

```bash
git --version
node --version
npm --version
cd samples/book-app-web
npm ci
npm test -- --run
npm run build
```

The Node version should be `v22.x`. If `npm ci` reports a lockfile problem, try `npm install` and tell the facilitator. Do not spend the workshop troubleshooting a failed install.

To check the live preview, run:

```bash
npm run dev -- --host 127.0.0.1 --port 5173
```

Open `http://127.0.0.1:5173` in the app's Browser preview and confirm the Book App appears. Stop the dev server after confirming it works. Bring any setup problem to the facilitator before the workshop.

### What we will do in class

You will use the existing Book App to add a small **Clear filters** feature. You will describe what success means, review a plan before allowing changes, work in an isolated session, and check the result with the diff, automated checks, and browser behavior. You will also use the existing Book App Reviewer as an example, create a focused read-only custom agent of your own, and test it against your change.

The facilitator will also demonstrate a preconfigured WorkIQ MCP connection. You only need to watch; you do not need WorkIQ access or setup. You are not expected to build an app from scratch, push code, or merge a pull request. After class, use the following three days to experiment with the app and workshop repository in your own worktree.

## Part 2: Facilitator runbook — 90 minutes

### Learning outcomes

By the end, participants should be able to:

1. Find a repository project and start an isolated Copilot app session.
2. Turn a small user need into observable acceptance criteria.
3. Review a plan before permitting implementation.
4. Explain that a custom agent is a role defined by instructions and selected tools, not a separately trained model.
5. Create and test a focused custom agent using the repository's Book App Reviewer as an example, and explain why its tool access fits its role.
6. Describe how MCP can connect an agent to tools and information beyond a repository.
7. Verify an agent's work by inspecting the diff and checking tests, build output, and browser behavior.

Use slides 6–27 for this session. Slides 1–5 are for orientation and the separate 20-minute preflight call.

| Time | Slides | Facilitator steps and participant activity | Learning check / evidence |
| --- | --- | --- | --- |
| 0–6 | 6–10 | Welcome participants. Set the outcome: coordinate, implement, and verify work in the app. Distinguish GitHub, Copilot, and the Copilot app. Introduce Describe → Plan → Build → Prove. | Participants can describe the workshop goal. |
| 6–15 | 11–13 | Open the Book App preview. Demonstrate title/author search, genre/status filters, changing stats, and an empty result. Introduce Clear filters and agree on observable success. | Participants can name the user need and success behavior. |
| 15–25 | 14–16 | Instructor demo: show project/session context, an isolated worktree, Plan mode, and reviewing the plan against the criteria before authorizing edits. | Participants can explain why we review a plan first. |
| 25–45 | 16 | Participants create a worktree from `main`, request a plan, compare it with the criteria, approve/revise it, and implement Clear filters. Coach them to inspect changes and avoid unrelated edits. | A focused change follows an approved plan. |
| 45–68 | 17–20 | Show the Book App Reviewer reviewing the implementation and surfacing the whitespace-only search edge case. Explain the agent's role, instructions, and tools, then show the role menu. Participants choose a focused role, create an agent with only the tools it needs, and test it against the current Clear filters change in the same worktree. | Each learner has created and tried an agent; they can explain its role, tool access, and what needs human verification. |
| 68–74 | 21 | Demonstrate the facilitator's preconfigured WorkIQ MCP connection with a safe, authorized example. Explain that MCP connects an agent to tools/data beyond the repository; participants observe only. | Participants can explain what the external tool contributed. |
| 74–85 | 22–25 | Track real evidence in Canvas, inspect the implementation diff and custom-agent output, run tests/build, and use Browser to check key filter states. Mark only observed results as complete. | Participants can report what they verified and which checks remain. |
| 85–90 | 26–27 | Debrief plan/build/review/refine/verify. Invite learners to name one useful app capability and choose an experiment for the next three days. Do not merge or push. | Each learner can name an app capability and a verified outcome. |

**Timing check:** 6 + 9 + 10 + 20 + 23 + 6 + 11 + 5 = 90 minutes.

### WorkIQ MCP demonstration

- The facilitator uses the preconfigured WorkIQ connection; participants do not need access or setup.
- Choose one short, safe example in advance and show only information you are authorized to share. Avoid private messages, personal data, confidential content, and attendee data.
- Make the tool call visible and identify the external context it returned. Explain that MCP connects the agent to a tool; the response is context to evaluate, not proof.
- If the connection is unavailable, explain MCP briefly from slide 20 and continue the hands-on. Do not troubleshoot during class.

### Three-day experimentation

Invite participants to experiment with the Copilot app and repository over the next three days, using their own worktree. Suggestions: try a new task prompt, start a second session, use the reviewer skill/agent, or inspect available MCP integrations. Do not promise that WorkIQ access is included.

### Session A prompt

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

After plan approval, ask the agent to implement the approved plan. If a criterion or validation step is missing, ask for a plan revision before implementation.

### Create and test a custom agent

Explain to participants: “An agent is Copilot configured for a kind of work. Its name, instructions, and selected tools create a focused role; it is not a new AI model. The Book App Reviewer can inspect and report, but it cannot edit the app. Other agents can design tests, investigate bugs, explain code, improve accessibility, build a small feature, or draft documentation.”

Show `.github/agents/book-app-reviewer.agent.md`. Point out its `name`, `description`, `tools`, role instructions, and read-only boundary. Explain that tools set what an agent is equipped to do, while instructions describe the job. Read/search tools are enough for reviewing, investigating, and explaining. Writing tests, changing code, or drafting docs requires edit access. Grant only the tools needed and inspect any changes; a narrow prompt guides behavior but is not a technical file-level permission boundary.

Ask each participant to choose one role from slide 18: code reviewer, test designer, bug investigator, accessibility helper, code explainer, feature builder, or documentation helper.

Have them send this prompt in their implementation session, replacing `[ROLE]`:
```text
Read `.github/agents/book-app-reviewer.agent.md` as an example. Create a custom agent for this role: [ROLE]. Focus it on the Book App's Clear filters change in `samples/book-app-web`. Choose a clear name and create a separate agent file under `.github/agents/`; do not modify the existing Book App Reviewer.

Give it the least tool access needed for the role. For a read-only role, allow only file-reading and search tools. If its role writes tests, code, or documentation, grant edit access only if needed and instruct it to limit changes to relevant files. Do not grant terminal, commit, or push tools. State its task, boundaries, and what it must report; require file paths and specific evidence, beginner-friendly explanations, and clear disclosure of checks it did not run. Show me the new agent definition and explain its role, tools, and limits. Do not run it yet.
```

Review the definition together. If it does not appear in the agent picker, reload/reopen the Copilot app. Keep working in the same project/worktree as the Clear filters implementation. Select the new agent and test it with this role-neutral prompt, replacing `[ROLE]`:

```text
Act as my [ROLE] agent for the Clear filters change in this worktree. Do the job described in your agent instructions, using the smallest useful scope. Do not commit or push. If your role is read-only, report code evidence and checks that still need to be run. If your role makes changes, summarize every file changed and why; do not claim tests, build, or browser checks passed unless you actually ran them.
```

Ask whether the agent did the selected job, stayed within its intended scope, and supported its output with evidence. If it edited files, inspect the diff and decide which tests/browser checks to run. Keep the agent and any changes in the participant's worktree; do not push or merge during class.

### Facilitator guardrails

- Keep the canonical Book App and course chapters intact; do not redirect learners to another sample or ask them to edit chapter instructions.
- Each participant uses their own checkout and worktree. Do not have the class share a working directory or work directly on `main`.
- Keep the Book App exercise focused: no dependencies, backend, database, external API, unrelated redesign, push, or merge. The instructor's separate WorkIQ MCP demo does not add an integration to the sample.
- If the new custom agent does not appear, confirm its definition is under `.github/agents/` in the participant's worktree and reload/reopen the app. If time runs out, have them inspect the definition and test it after class. If Canvas is unavailable, track the same four items on a plain-text or physical board and label it as a fallback.
- If implementation runs long, protect time for at least one verification path. Let the custom-agent creation/testing continue after class rather than claiming an agent worked when it was not tested.

For the longer setup notes, recovery guidance, and complete verification checklist, see the [facilitator guide](./copilot-app-workshop-facilitator-guide.md).

### Official app setup reference

- [Getting started with the GitHub Copilot app](https://docs.github.com/en/copilot/get-started/quickstart-copilot-app)
