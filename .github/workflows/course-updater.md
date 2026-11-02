---
name: "Course Updater"
description: "Weekly check (Mondays) for new GitHub Copilot app features and updates. Opens a PR if the course content needs updating."
on:
  schedule: weekly on monday
  workflow_dispatch:
engine:
  id: copilot
  args: ["--allow-url=https://github.com"]
permissions:
  contents: read
  pull-requests: read
tools:
  bash: ["curl", "gh"]
  edit:
  github:
    toolsets: [repos, pull_requests]
safe-outputs:
  allowed-domains:
    - github.com
  create-pull-request:
    labels: [automated-update, copilot-app-updates]
    title-prefix: "[bot] "
    base-branch: main
---

# Check for Copilot App Updates

You are a documentation maintainer for the Copilot App for Beginners repository. Your job is to check for recent updates to the GitHub Copilot app and determine if the course content in chapters 00 - 07 needs updating.

## Step 1 — Gather recent Copilot app updates

Use the authenticated GitHub MCP tool `get_file_contents` to read `changelog.md` on the `main` branch of `github/app` (the GitHub Copilot app changelog). Extract the latest entries from the past 7 days.

Use the authenticated GitHub MCP tools `list_releases` and `list_commits` to check the latest releases and commits in `github/app`. Only include updates from the past 7 days.

Only consider features that have shipped in a stable GitHub release. Use the GitHub release metadata as the source of truth and exclude every release where `draft` or `prerelease` is `true`. Do not use version names, changelog entries, or wording such as "production-ready" to override that metadata. A changelog entry or commit is eligible only if you verify that it is included in a stable release published within the past 7 days. Ignore unreleased changes and changes available only in prerelease versions.

If a shell `gh` command is denied or cannot authenticate, continue with the GitHub MCP tools. Release notes and commits are valid alternative sources when `get_file_contents` cannot read the changelog.

If the authenticated MCP reads also fail, report the error with `missing_data` or `missing_tool` and stop. Do not assume that the repository is private or report that no updates are needed without source data. An incomplete check must fail the workflow.

Look for:

- New features or capabilities (e.g., new views, canvases, automations, or MCP/agent support)
- Significant changes to existing features (renames, moved settings, deprecations)
- New customization options (e.g. skills, custom agents, MCP servers, canvases, automations)

## Step 2 — Check for existing open PRs to avoid duplicates

Before doing any content comparison, use the authenticated GitHub MCP `list_pull_requests` tool to list open pull requests in this repo. Select the PRs with either the `automated-update` or `copilot-app-updates` label. Read their titles and descriptions to understand which features or changes each PR already covers. Build a list of features that are **already addressed** by existing PRs — you must exclude those features from any updates you propose later. If every feature you found in Step 1 is already covered by an open PR, stop here and call `noop` to report that no new updates are needed.

If the PR lookup fails, report `missing_data` or `missing_tool` and stop. Do not treat a failed lookup as an empty PR list.

## Step 3 — Compare against the current course content

This course targets beginners, so only include content changes that cater to that audience. For example, if a new feature is advanced, marked as experimental, or otherwise doesn't qualify as a "beginner" level feature, don't include it in the course content since we don't want to overwhelm learners. Determine what is most relevant and helpful for beginners learning about the GitHub Copilot app. If a feature is "nice to have" but not critical to a "for beginners" course, it can be omitted.

Read all of the readme files in the repo and compare the features documented there against what you found in Step 1.
Identify:

- **Missing features** — new capabilities not yet documented
- **Outdated information** — features that have been renamed, moved, or significantly changed (including UI labels, menu names, or button text shown in screenshots)

If there is nothing new or everything is already up to date, stop here and call `noop` to report that no updates are needed.

## Step 4 — Update the course content

If updates are needed, make a decision on which chapter(s) need to be updated.

If the new information can be added to existing chapter(s), edit those chapters to include refinements, new sections, or updated information as needed. Remember that this course targets beginners, so ensure that any new content is explained clearly and simply, with examples if possible. Do not remove or invalidate existing screenshots unless the change makes them clearly incorrect.

## Step 5 — Open a pull request

Create a pull request with your changes, using the `main` branch as the base branch. The PR title should summarize what was updated (e.g., "Document the new canvas templates picker"). The PR body should list:

1. What new features or changes were found
2. What sections of the course were updated
3. Links to the source announcements

The PR should target the `main` branch and include the labels `automated-update` and `copilot-app-updates`.

Match each feature to the version in its changelog heading and release record. Do not assign a feature to a different release.
