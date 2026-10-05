---
name: "Course Updater"
description: "Weekly check (Mondays) for new GitHub Copilot app features and updates. Opens a PR if the course content needs updating."
on:
  schedule: weekly on monday
  workflow_dispatch:
tools:
  bash: ["date"]
  edit:
  github:
    toolsets: [repos]
mcp-scripts:
  fetch-app-updates:
    description: "Read changelog sections for recent Copilot app releases and return release and commit details from the past 7 days."
    run: |
      set -euo pipefail
      since="$(node -p 'new Date(Date.now() - 7 * 86400000).toISOString().replace(/\.\d{3}Z$/, "Z")')"
      releases="$(gh api --paginate --slurp 'repos/github/app/releases?per_page=100' |
        jq --arg since "$since" '[.[][] | select(.published_at != null and .published_at >= $since) | {tag_name, published_at, html_url, body}]')"
      tags="$(printf '%s' "$releases" | jq 'map(.tag_name)')"
      printf '%s\n' '## Changelog: https://github.com/github/app/blob/main/changelog.md'
      gh api 'repos/github/app/contents/changelog.md?ref=main' --jq '.content | @base64d' |
        jq -Rrs --argjson tags "$tags" '
          [split("\n## ")[] | select(split("\n")[0] as $tag | $tags | index($tag)) | "## " + .] as $sections |
          if ($sections | length) != ($tags | length) then
            error("Missing changelog sections for recent releases")
          else
            $sections | join("\n")
          end'
      printf '\n## Releases since %s\n' "$since"
      printf '%s\n' "$releases"
      printf '\n## Commits since %s\n' "$since"
      gh api --paginate --slurp "repos/github/app/commits?since=$since&per_page=100" |
        jq '[.[][] | {sha, html_url, message: .commit.message, date: .commit.committer.date}]'
    env:
      GH_TOKEN: "${{ secrets.GH_AW_GITHUB_TOKEN }}"
  fetch-open-update-prs:
    description: "Return all open PRs with the automated-update or copilot-app-updates label. An empty array means no matching PRs."
    run: |
      set -euo pipefail
      gh api --paginate --slurp "repos/$GITHUB_REPOSITORY/pulls?state=open&per_page=100" |
        jq '[.[][] | select(any(.labels[]; .name == "automated-update" or .name == "copilot-app-updates")) | {number, title, body, html_url}]'
    env:
      GH_TOKEN: "${{ secrets.GH_AW_GITHUB_TOKEN }}"
post-steps:
  - name: Require a complete course update check
    if: always()
    env:
      GH_AW_SAFE_OUTPUTS: ${{ steps.set-runtime-paths.outputs.GH_AW_SAFE_OUTPUTS }}
    run: |
      node <<'NODE'
      const { readFileSync } = require('node:fs');
      const outputPath = process.env.GH_AW_SAFE_OUTPUTS;
      if (!outputPath) {
        throw new Error('The course update output path is missing.');
      }
      const outputs = readFileSync(outputPath, 'utf8')
        .split(/\r?\n/)
        .filter(line => line.trim())
        .map(line => JSON.parse(line));
      const completeTypes = new Set(['create_pull_request', 'noop']);
      if (!outputs.length || outputs.some(output => !completeTypes.has(output.type))) {
        const types = outputs.map(output => output.type).join(', ') || 'no output';
        throw new Error(`Course update check is incomplete (${types}). See the agent logs.`);
      }
      NODE
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

Call `fetch-app-updates` (no inputs needed). This authenticated tool reads:

- https://github.com/github/app/blob/main/changelog.md — GitHub Copilot app changelog
- Releases and commits in `github/app` from the past 7 days

Use the returned changelog, release notes, and commit details to identify updates from the past 7 days. Do not use `web-fetch`, `curl`, or shell `gh` commands for these checks.

If this tool or `fetch-open-update-prs` fails, report the error with `missing_data` or `missing_tool` and stop. Do not assume that a source repository is private, report that no updates are needed, or edit course content without the required source data. An incomplete check must fail the workflow.

Look for:

- New features or capabilities (e.g., new views, canvases, automations, or MCP/agent support)
- Significant changes to existing features (renames, moved settings, deprecations)
- New customization options (e.g. skills, custom agents, MCP servers, canvases, automations)

## Step 2 — Check for existing open PRs to avoid duplicates

Before doing any content comparison, call `fetch-open-update-prs` (no inputs needed). It returns all open pull requests in this repo that have the `automated-update` or `copilot-app-updates` labels. Read their titles and descriptions to understand which features or changes each PR already covers. Build a list of features that are **already addressed** by existing PRs — you must exclude those features from any updates you propose later. If every feature you found in Step 1 is already covered by an open PR, stop here and call `noop` to report that no new updates are needed.

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
