# Troubleshooting Reference

Use this reference when a learner gets stuck. Start with the related chapter, then check the symptom and next action.

## Chapter 00: Setup

Related chapter: [00 Setup](../00-setup/)

| Symptom | Likely cause | Try this |
|---|---|---|
| Sign-in fails | Account, network, SSO, or GitHub Enterprise Server URL issue | Confirm the account, browser sign-in, Enterprise Server URL if used, and network access |
| App access is unavailable | Copilot plan, own model provider, or organization policy | Confirm a Copilot plan or a configured model provider. For Business or Enterprise, confirm the **GitHub Copilot app** policy is enabled (it is separate from the Copilot CLI policy) |
| Git is not detected | Git is missing or not on PATH | Install Git and restart the app |
| Repository does not appear | Repository access or picker filter | Check account access, organization membership, repository permissions, and whether to add a local folder, GitHub repo, or URL |
| A chat cannot summarize the repo | Repo not connected or context is too broad | Reconnect the project and ask for a small overview of the course repo |

## Chapter 01: Tour the App

Related chapter: [01 Tour the App](../01-tour-the-app/)

| Symptom | Likely cause | Try this |
|---|---|---|
| Learner is unsure which mode to use | Modes sound like skill levels | Use Chats for exploration, Plan when you want an approach first, Interactive when you want to steer each step, and Autopilot for a clear low-risk task |
| Responses are slow or costly | Model, reasoning effort, or context is larger than needed | Lower reasoning effort for simple tasks and attach only useful context |
| Settings look different from screenshots | App version or platform difference | Check the app version and screenshot manifest |
| Voice dictation does not work | Microphone permission or local transcription model | Check OS microphone permission, voice settings, downloaded model, shortcut, and language support |
| Keyboard shortcut is missing | Platform or app version difference | Open Help or settings and use the shortcut list for the installed version |

## Chapter 02: Sessions, Worktrees, and Context

Related chapter: [02 Sessions, Worktrees, and Context](../02-sessions-worktrees-context/) and [Git Worktrees](git-worktrees.md)

| Symptom | Likely cause | Try this |
|---|---|---|
| Session edits appear in an unexpected folder | Worktree path or branch confusion | Check the session details, branch name, and worktree path in the app |
| Worktree is missing | Folder was moved or deleted manually | Prefer app cleanup. If already deleted, close the session and recreate the work from the branch or PR if available |
| Two sessions conflict | They edited the same files or shared resources | Pause one session, compare diffs, and decide which branch is the source of truth |
| Web server fails to start | Port already in use | Stop the unused server or run the second session on another port, such as `5174` |
| Session differs from main checkout | Dependencies, branch contents, environment, or generated files differ | Run install and validation commands in the session worktree |
| Context is noisy | Too many files or broad prompts | Use focused `@` file or folder references and smaller tasks |
| Responses include too much unrelated detail | App-wide instructions or context are noisy | Keep **Settings → Sessions** app instructions short and attach only relevant files |
| Branch names are hard to recognize | Branch prefix is not configured | Set a project or app branch prefix that identifies GitHub Copilot app sessions |

## Chapter 03: Development and GitHub Workflows

Related chapter: [03 Development and GitHub Workflows](../03-development-workflows/)

| Symptom | Likely cause | Try this |
|---|---|---|
| Tests fail only in one session | Dependency or branch mismatch | Reinstall dependencies in that worktree and check branch contents |
| Browser preview does not update | Dev server, hot reload, or wrong port | Restart the server in the correct worktree and confirm the browser URL |
| Diff is hard to trust | Too many unrelated changes | Ask the agent to explain the diff, then split or revert unrelated edits |
| Pick and Polish changes hurt accessibility | Visual update changed contrast, layout, or labels | Review with accessibility goals and rerun tests or manual checks |
| Screenshot does not show expected state | Window was hidden, covered, or scrolled elsewhere | Bring the app forward, expose the target panel, and capture the visible window |
| Issue or PR is missing from My work | Filters or permissions | Clear filters, check repository access, and confirm assignment or review request |
| Cannot push a branch | No write access to upstream | Use a fork or a repository where the learner has write access |
| CI fails but local tests pass | Different environment, secrets, or branch protection | Read the failing check log and compare Node version, commands, and secrets |
| PR remains blocked | Required reviews, checks, branch protection, or conflicts | Triage in this order: failing checks, merge conflicts, required reviews, stale reviews, branch rules |
| Agent Merge is unavailable | Policy, permissions, or repository settings | Treat Agent Merge as advanced and use manual review or merge flow instead |
| Parallel sessions duplicate work or collide | Tasks were not independent, or branches touched the same files | Pause, compare diffs, assign one session as the source of truth, and resolve conflicts manually |

## Chapter 04: Skills and Custom Agents

Related chapter: [04 Skills and Custom Agents](../04-skills-custom-agents/)

| Symptom | Likely cause | Try this |
|---|---|---|
| Copilot ignores project style | Instructions are missing or too broad | Put stable project guidance in `.github/copilot-instructions.md` |
| Skill does not seem to apply | Skill location, metadata, or prompt mismatch | Check `.github/skills/.../SKILL.md` and prompt for the skill's purpose. In the app, open **Customize → Skills** and filter to **Project** |
| Cannot find Skills or Custom Agents | Looking in Settings instead of the relevant picker | Open **Customize → Skills** for skills. Use `/agent` or the prompt-box agent picker for custom agents |
| New custom agent is missing | Profile saved outside the worktree or not reloaded | Check `.github/agents/book-app-explainer.agent.md` in the current worktree. Follow the chapter's same-session restart instructions |
| Custom agent cannot run tests | The explainer has read and search tools only | Return to the default agent; don't broaden the explainer's tools |
| Agent has too many tools | Toolset adds noise and risk | Disable tools not needed for the task |

## Chapter 05: MCP Servers and Plugins

Related chapter: [05 MCP Servers and Plugins](../05-mcp-plugins/)

| Symptom | Likely cause | Try this |
|---|---|---|
| Cannot find MCP or Plugins in Settings | Customization is in the sidebar | Open **Customize → MCP** or **Customize → Plugins** |
| MCP server fails | Authentication, network, or policy issue | Check connection status, URL, credentials, and organization policy. Don't put credentials in prompts or repository files |
| Plugin capability is missing | Plugin disabled or its skill hasn't loaded | Check **Customize → Plugins**, run `/skills reload`, and look for a plugin-prefixed skill name. Follow the chapter's restart instructions if needed |
| Agent cannot use an integration | Read-only explainer is still selected or tool access is blocked | Select **Default agent**, then check approvals and policy |
| Integration is blocked by policy | Installation or external access isn't permitted | Read the example and expected output, record the limitation, and continue without changing policy |

## Chapter 06: Canvases

Related chapter: [06 Canvases](../06-canvases/)

| Symptom | Likely cause | Try this |
|---|---|---|
| Canvas does not open | `/create-canvas` missing, or extension syntax, dependency, or reload issue | Retry `/create-canvas`, or keep the same board as markdown in the session |
| Canvas state looks stale | Stored state and visible UI are out of sync | Refresh the canvas or rerun the action that updates state |
| Agent action fails | Capability name or input schema mismatch | Check the action name, required fields, and stored state |
| Canvas contains private content | Shared surface was used like private notes | Remove secrets, private repo details, and customer data before publishing |

## Chapter 07: Automations

Related chapter: [07 Automations](../07-automations/)

| Symptom | Likely cause | Try this |
|---|---|---|
| Manual automation does not run | App, project, or tool dependency is unavailable | Confirm the app is open, the project exists, and required tools are installed |
| Schedule does not run | Local machine asleep or cloud setting unavailable | Use manual run for beginner exercises or verify cloud automation prerequisites |
| Cloud automation is unavailable | Policy, billing, repository, or permission issue | Treat it as advanced and use the provided screenshots or a simulated flow |
| Issue trigger fires too often | Trigger is too broad | Narrow the repository, labels, issue query, or tool permissions |
| Automation result is unsafe to publish | Run history includes private data | Redact or recreate with sample repository data |

## General rule

If the agent says a task is complete, still inspect the evidence. A good course workflow ends with visible validation: Diff, tests, build, browser preview, PR checks, or review result.
