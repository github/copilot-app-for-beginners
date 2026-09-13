# Glossary

Quick reference for beginner terms used in this course.

## Agent Merge

An advanced finishing workflow. Official docs enable it with the **agent merge** toggle at the top of a pull request view. It can read the pull request, work on blockers, and merge when GitHub allows. Use it only after you understand the diff, tests, required reviews, and branch protection rules.

## Automation

A saved agent task that can run on demand, on a schedule, or in advanced cases from repository events. Automations should have a clear prompt, limited tools, and a review path.

## Autopilot

A session mode where the agent works with high autonomy. Use it for a well-defined, low-risk task after you understand the scope.

## Branch

A named line of work in git. A branch lets you make changes without changing the main line until you are ready to merge.

## Canvas

A shared board created with `/create-canvas` and opened in the session side panel. You describe what you want on it, and the app builds the canvas. In this course you ask for a session board: the plan, the checks you ran, and the next decision.

## Chat

A lightweight GitHub Copilot app conversation for questions, brainstorming, or repository exploration. The sidebar calls this **Chats**. A chat does not create a branch or worktree, which makes it safe for exploring before you change code.

## CI check

An automated check that runs on a pull request or branch. It may run tests, builds, linting, or security scans. CI stands for continuous integration.

## Cloud sandbox

A GitHub-hosted environment where an agent can work away from your local machine. Availability depends on plan, policy, repository settings, and permissions.

## Create from

The sidebar control next to a project name that starts a session from a branch, issue, or pull request.

## Custom agent

A specialized agent configuration for a role or workflow, such as review, documentation, or testing. Its profile defines instructions and available tools. In the GitHub Copilot app, choose one with `/agent` or the agent picker. [Chapter 04](./04-skills-custom-agents/README.md#custom-agents-define-a-role-and-its-tools) includes a small read-only example.

## Diff

A view of what changed between two versions of files. In this course, the diff is one of the main places where you inspect agent work before accepting it.

## Guided fix

Asking GitHub Copilot to address a specific review comment or failing check while the diff and validation evidence stay visible. Official pull request views may also show **Fix** and **Fix failing checks**. It keeps follow-up work small and reviewable.

## Home

The app landing view. Start a session, connect a repository, and see **Up next** GitHub items from connected repos.

## Interactive

A session mode where you and the agent work step by step. The agent waits for your input more often than in Autopilot.

## Inner loop

The local development cycle on your machine: review, debug, test, and preview a change before it goes to GitHub.

## Local sandbox

A local execution environment with restrictions on file system, network, or system access. It keeps work closer to your machine while limiting what the agent can reach.

## Model

The AI system used for a response or session. Different models may vary in speed, cost, reasoning ability, and output style. Some builds offer **Auto**, which chooses a model from the task.

## Model Context Protocol (MCP) server

A tool server that uses Model Context Protocol to connect Copilot to external tools and data. MCP servers are useful, but they can add permissions, credentials, and complexity. In the GitHub Copilot app, manage them from the sidebar **Customize** tab.

## My work

The app view that gathers your GitHub issues, pull requests, review requests, and failing checks in one inbox. Official default sections are **All**, **Active**, **Review requests**, and **Done**. It supports search qualifiers such as `repo:` and `is:pr`.

## Outer loop

The GitHub side of the same workflow: find work in My work, start sessions from issues, open pull requests, and ask Copilot to address review comments and failing checks.

## Pick & Polish

A browser-preview feature in the GitHub Copilot app. Select **Pick & Polish**, choose a rendered page element, and the app attaches that element to the prompt as context for a focused UI change.

## Plan mode

A session mode where the agent proposes a plan first. You review and approve before it implements.

## Plugin

A packaged extension that can add capabilities to the GitHub Copilot app. Plugins may include custom agents, skills, hooks, MCP server configurations, or LSP server configurations. In the app, plugins can also package canvas extensions. Enable only what a workflow needs. Browse and install plugins from the sidebar **Customize** tab.

## PR

Pull request. A GitHub request to review and merge changes from one branch into another.

## Prompt injection

A risk where untrusted text, such as an issue title or body, tries to steer the agent into unintended actions. Read-only tasks and least-privilege tool choices reduce the risk.

## Reasoning effort

A setting that controls how much thinking the model spends on a task. Higher effort can help complex work, but may be slower or more expensive.

## Rubber duck

A built-in critic agent, invoked with `/rubber-duck`, that reviews a plan, diff, tests, or design and points out weaknesses before you accept the work.

## Session

A GitHub Copilot app workspace where an agent can plan, edit, run commands, inspect diffs, and report progress. Sessions may run in a local repository, a new worktree, or a cloud sandbox.

## Skill

Reusable guidance that helps the agent handle a specific kind of task. In this course, repo-local skills are the beginner-friendly way to add focused expertise. In the GitHub Copilot app, find them under **Customize → Skills**.

## Workspace panel

The session side panel for diffs, terminal, browser preview, and other work surfaces. Open it with **Toggle panel** in the upper-right corner.

## Worktree

A second working folder attached to the same git repository. In the GitHub Copilot app, a session worktree usually has its own branch so parallel work does not collide with your main checkout.
