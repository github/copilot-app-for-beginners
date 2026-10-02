# GitHub Copilot app UI Map

- app_version: 1.1.26
- captured: 2026-09-30, checked again on 2026-10-01 for 1.1.26 (macOS, `demo`
  persona, Streamer Mode on)
- privacy: project names, session names, pull request titles, and the account name
  are redacted to `<placeholder>`. Regenerate with
  [map-app.sh](../sample_codes/macos-accessibility/map-app.sh) from a sanitized
  account, then re-redact before committing.

A factual reference for grounding course steps and screenshots in the app's real
UI. Menus are always mappable. The other sections were checked with
Accessibility in a process-scoped persona. Re-run `map-app.sh` after an app
update and diff against this file.

## Menus

- **GitHub Copilot**: About GitHub Copilot · Settings… · Check for Updates… · Services · Hide… · Quit
- **File**: New Session · New Session from Recent · New Chat · Open URL From Clipboard · Create from Local Folder or Repository · Create from GitHub · Create from URL · Close Window
- **Edit**: Undo · Redo · Cut · Copy · Paste · Select All · Writing Tools · AutoFill · Start Dictation… · Emoji & Symbols
- **View**: Toggle Sidebar · Toggle Review Panel · Toggle Terminal · Command Palette · Back · Forward · Actual Size · Zoom In · Zoom Out · Enter Full Screen
- **Window**: Minimize · Zoom · Bring All to Front
- **Help**: Documentation · Keyboard Shortcuts · What's New · Manage Copilot Subscription · Automations · MCP Servers · Skills · Share Feedback · Run Health Check · Show Home Tips Again · Credits

## Onboarding (first run)

- Sign-in screen: **Sign in to GitHub** · **Sign in to GitHub Enterprise Cloud
  (*.ghe.com)** · Accessibility settings. If the app already has an account,
  it shows **Continue as @`<login>`** and **Use a different account** instead.
- **Connect your repositories. We've selected these based on your activity.**:
  Add local repositories · Select from GitHub (suggested repositories, not
  selected) · "Nothing selected yet. Repositories can be added anytime." ·
  **Continue**.
- 1.1.25 and 1.1.26 have no theme step. **Continue** opens the New view, and a
  one-time tip about **Customize** can appear. GitHub Docs can still describe a
  theme step.
- The app stores the state in the `app_state` table of
  `<persona home>/.copilot/data.db` (key `copilot-onboarding`, field
  `hasCompletedOnboarding`). To see onboarding again in the `demo` persona,
  close it, back up `data.db`, `data.db-wal`, and `data.db-shm`, set the field
  to `false`, and launch it again. The app sets the field to `true` when
  onboarding ends.

## Sidebar (navigation)

- Toggle sidebar (checkbox) · Search · Back · Forward · Resize sidebar
- **Quick links**: New · Pull requests · Issues · Automations · Customize · More
  - **More** (AXPopUpButton) has one item, **Edit sidebar...**. That dialog has
    a check box for each Quick link (New, Pull requests, Issues, Automations,
    Customize) to show or hide it.
- **Projects** heading: **Configure sessions** · **New project or session** (+)
  - Configure sessions: Grouping · Ordering · Show (Project, Branch) · Status ·
    PR · Environment · Source · Reset filters · Collapse all · Mark all as read
  - New project or session (+): Chat · "Start session in" `<project>` (one row
    per visible project) · Add GitHub repository · Clone repository · Open folder.
    Its footer shows "New session, Command + N. New chat, Command + Shift + N."
  - **Chats** row, with **New chat** (+) on hover. In 1.1.26 the row appears
    only when at least one chat exists. **Show** and **Edit sidebar** have no
    option for it. Start the first chat with **+** > **Chat**.
  - One row per connected project. On hover: **Create from…** ("Create project
    from pull requests, branches, or issues in `<project>`") and **New session
    in `<project>`** (+). Right-click: New session · Create from… · Show in
    Finder · Open on GitHub · Settings · Hide · Customize… · Manage sessions ·
    Remove repository
  - Session rows (right-click): Rename · Pin · Mark as unread · Show in Finder ·
    Copy · Open in… · Create nested session · Archive · Delete. Chat rows have
    no Open in… or Create nested session, and add Share as secret gist.
- **User profile and settings** (bottom): "`<user>`, open user menu" · Share feedback · Settings

## Pull requests and Issues views

- Heading, repository picker (AXComboBox, **All repositories** or
  `<owner>/<repo>`), and **Open detail panel**. Issues also has **New issue**.
- Pull requests tabs: Authored by me · Assigned to me · Involves me · Review
  requests · Done · New view (+)
- Issues tabs: Assigned to me · Created by me · Mentioning me · Done · New view (+)
- **Filter: `<tab>`** (filter icon) shows or hides a query box with Simple and
  Query modes. Defaults: `state:open author:@me` (Authored by me) and
  `state:open assignee:@me` (Assigned to me).
- The repository picker selection is separate for each view and stays when you
  change tabs. A typed `repo:` term sets the picker to **Custom** ("managed by
  query filter") and is removed when you change tabs.
- Pull request detail: New session (+ New session options: New session, Chat) ·
  Review (Comment, Approve, Request changes) · Ready to merge · Close detail
  panel; tabs Overview and Changes. A failing check shows "Some checks were not
  successful", "Failing (n)", and an options menu (Open on GitHub, Re-run).
  The PR tab in a session's review panel adds a **Check status** heading with
  **Fix failing checks** (options: Fix with instructions).
- **Ready to merge** (merge-readiness button in the PR header and the session
  header) opens the **Merge pull request** panel: **Agent merge** toggle
  ("Automatically address reviews, fix CI failures, and resolve conflicts."),
  readiness heading, checks with **Fix failing checks**, and comment status.
  Do not press merge controls during capture.
- Issue detail: New session (+ options) · Assignees · Labels · Type · Add
  property · Create sub-issue · Close issue · Comment

## Automations view

- Heading with **New automation**. Empty state: "Set up automations",
  **Start automating**, template cards, and a Skills list with a
  **New automation** button for each skill.
- After an automation exists: Search automations… · Templates · New automation;
  **Your automations** cards (Trigger, description, Environment, last run, Run)
  and **Recent runs**.
- New automation form: Name · Trigger (default **Daily**; Manual, Hourly,
  Daily, Weekly, CRON, Issue, Discussion comment, Discussion opened, Discussion
  updated, Pull request, Sub issue added) · Hours (00:00–23:00, default 09:00) ·
  Minute (:00, :15, :30, :45) · Run in the cloud · Prompt (Mode default
  Autopilot, model) · project picker ("Select project"; "Without a project,
  this automation will run as a chat.") · **Workspace** picker after a project
  is chosen (New worktree, Current checkout) · Cancel · Create + "Create
  automation options" → Create and run. **Create** stays disabled until the
  prompt has text.
- CRON trigger: **Expression** fields min · hour · day · month · weekday, each
  with a hint, "Evaluated in local time.", a preview such as "Runs at 8:00 AM
  every day.", and errors such as "Invalid CRON, Minute must be 0 to 59."
- Run in the cloud adds **Add another trigger** and **Tools** (default "All
  tools selected"; sections Issues, Pull Requests, Discussions, Repos, Actions,
  Labels, Code Security). Selecting one tool while all are selected clears that
  tool only.
- Automation detail: name button opens **Automation details** (Tokens, Context,
  Session spend, Environment, Schedule, Next run, Runs, Edit automation, Disable
  automation, Delete automation) · Open as chat · Edit · Run automation. Edit
  opens **Edit automation** with **Save automation**.

## Customize view

- Tabs: Featured · MCP · Plugins · Skills · Extensions · Canvas · Installed;
  tab-specific search ("Search MCP servers", "Search plugins", "Search skills")
  and **Add** (MCP Server…, Plugin…, Skill…, Canvas from URL…).
- MCP: Featured cards and **Available** by category. Search a server name, then
  **Add server** on its row opens a dialog titled with the server name (About,
  Configuration: Server name, Server type (Local/HTTP/SSE; the **Server type**
  label is new in 1.1.26), URL, Headers, OAuth Client ID, Timeout). Installed
  servers show a connected icon, an enabled toggle, and Actions (right-click
  the row: Disable, Edit configuration, View on GitHub, Remove; Remove asks
  "Remove `<name>`?").
- Plugins: Featured cards and **Available** marketplace rows (copilot-plugins,
  awesome-copilot). A marketplace is searched only after you expand it. The gear
  icon is **Manage marketplaces** (Source field, Add marketplace). Installed
  plugins have Actions (Update, Uninstall) and an enabled toggle.
- Skills: Installed list with filters All · Project · Built-in. There is no
  Personal filter.
- Installed: sections that include **Extensions** and **Canvas** (with a
  count). Canvas lists the Built-in Editor, Browser, and Terminal canvases,
  then Personal (user-scoped) canvases. A personal canvas has no uninstall
  action. Its details show only Copy path and Reveal in Finder, so delete
  `~/.copilot/extensions/<name>` to remove it.

## Session composer

- AXTextArea **Message** — placeholder: "Ask anything. Use / for commands, @ files, & sessions, # issues..." (in Plan mode: "Plan a task. …")
- AXPopUpButton **Add context & more** · **Mode: `<mode>`** · model and
  reasoning (for example "GPT-6.1 Sol · Medium") · Set up voice dictation · Send message
- Mode menu: Interactive ("Step-by-step collaboration") · Plan ("Plan first,
  execute when ready") · Autopilot ("End-to-end execution without
  interruption") · **Tool permissions** (submenu: Always ask · Assisted
  (Experimental) · Approve all). A new 1.1.26 profile defaults to **Approve
  all** (`permission-mode-default-on` in `app_state`).
- Model and reasoning menu: Auto · Model (submenu: Claude Opus 5.5, Claude
  Sonnet 5.5, GPT-6.1 Sol, GPT-6 Astra, GPT-5.6 Sol, and others, then More
  models) · Effort · Context window. The last model you pick becomes the
  default for new sessions, so restore it after a test.
- AXComboBox **Project: `<project>`** (or **Chat**)
- AXPopUpButton **Workspace: `<choice>`, branch: `<branch>`** — menu heading
  **Where to work**: New worktree ("Separate directory for each session") ·
  Current checkout ("Work in the existing checkout") · Cloud ("Runs in a cloud
  sandbox") · Base branch (submenu). The label reads "New worktree · main".
  The app remembers the last choice across views and restarts. **Create from**
  always makes a new worktree.
- **Agent: `<agent>`** picker appears only when a custom agent is loaded (menu:
  Default agent, then custom agents). `/agent` ("Choose a custom agent for this
  session.") lists Default and custom agents. A new agent file needs an app
  restart before it appears.
- **Review plan** replaces the composer after a Plan-mode plan. Options:
  Approve and implement this plan (switches to Autopilot) · Exit plan mode and
  I will prompt myself (returns to Interactive) · Suggest changes to the plan…
  (text field) · Cancel · Continue. Each option shows a short badge, and its
  Accessibility label is the badge, a period, and the option text. Badges have
  changed between versions, so find options by their text, and do not use the
  badge in course text. A mouse click on an option submits it at once. AXPress
  only selects an option, and **Continue** or Return then submits the selected
  option (the first option by default). The plan also opens in a **Plan** tab
  in the review panel. The agent often asks a **Question** first (answer
  options, a free-text answer field, Skip, Continue).
- Items above the composer: **Changes +n −n** (Accessibility label "Open
  changes, Command + Backslash"; it opens the **Changes (n), +n, -n** tab),
  **PR #n**, and **Background n**. **Background n** opens **Background
  activity**: Running and Completed tasks, a Stop button for each running task,
  and a **Detached** label on detached tasks. An attached running task keeps
  the turn open.
- `/context` opens the session information menu (branch from base, Remote
  control, Path, Project, Session name, Session ID, Changes, Tokens, Context bar
  with Toggle breakdown, Session spend). It needs an active conversation: as the
  first message of a new session, **Send** and Return do nothing (1.1.26).
- `/agent` appears in the `/` list only after a custom agent is loaded.

## Session view and review panel

- Header: `<session title> · <repo>/<branch>` (long branch names are shortened
  with an ellipsis) · Run · Open in Visual Studio Code · Open in other apps ·
  **Create PR** (with Create PR options) when the branch has changes
- **Changes** tab toolbar (1.1.26): scope menu ("Uncommitted n files, changes
  scope": Committed · Uncommitted) on the left; on the right, branch actions
  for `<branch>` (Commit changes · Push changes · Rename branch) · Collapse all
  files · Diff view options · Show file tree.
- **Toggle panel, Command + Option + B** opens the review panel (the View menu
  item is still **Toggle Review Panel**). On the New view, the menu item is
  visible and enabled but does nothing, so submit a first prompt (or use
  **Create from**) before you open the panel. A new panel shows a list:
  Changes · Browser · Terminal · Files · Canvas. **Maximize panel, Command +
  Option + E** widens it.
- **Add tab, Command + T** (+): Changes · Terminal · Browser · Files · Side chat ·
  Insights · Canvas. **Canvas** opens a submenu with installed canvases, then
  "Discover more": Import canvas from gist/URL · Import canvas from repo. Before
  the first prompt of a session, the submenu shows only the import items.
- Sidebar session row > right-click > **Delete** opens **Delete session?**
  ("Permanently deletes `<name>` and all its files (about n MB)", "Uncommitted
  changes are backed up to a recovery branch before deletion", Don't ask
  again, Cancel, Delete session). The app then removes the session branch.
  Sessions from **Create from** > `main` are all named **main**. Identify a row
  by its Accessibility label, which includes "Last updated …".
- Browser tab: URL field, Light/Dark preview theme, **Pick & Polish,
  Command + Shift + C**.
- **Resize panel** splitter (AXValue 30–80) responds to Left/Right arrow keys
  when focused.

## New content

- Composer for a chat or selected project
- Project picker: Search · Chat · connected projects · Add GitHub repository · Clone repository · Open folder
- Three suggested prompt cards that change between visits
- Footer: "GitHub Copilot uses AI. Check for mistakes."

## Settings dialog

- Standard categories: General · Accounts · Sessions · Themes · Accessibility ·
  Voice dictation · Customize · Model providers · Experimental, then a
  **Projects** list. A project page has **Show in sidebar** and sandbox settings.
- The General category can show the current app version. Remove that version
  from course screenshots because it changes frequently.
- Sessions > **Default branch prefix** has a **Reset default branch prefix**
  button that restores `%username%-`.

## Notes for the course

- Enable and verify Streamer Mode before mapping or capturing. It hides
  unreleased features that the public cannot access.
- The app's docs can still say "My work". Follow the app: the sidebar has
  separate **Pull requests** and **Issues** views.
- "Chats" and connected repositories appear under "Projects".
- The **+** (**New chat**) on the **Chats** row, and the **+** and **Create
  from** icons on each project row, appear only while the pointer is over that
  row. Screenshots taken without hover do not show these controls, so do not
  report them as missing. Course steps should tell learners to point to the
  row first. The **+** next to the **Projects** heading is always visible.
- The **Start session in** group of the Projects **+** menu lists visible
  projects. A first-run learner has no project yet, so hide the project
  (Settings > project > Show in sidebar) to show their menu, then show it again.
- **New session** on a project opens the New view with that project selected.
  The session is created when you submit the first prompt.
- In the **Create from** dialog, Return on a search that matches no branch
  creates a new local branch with the typed text. Check the search text before
  you press Return.
