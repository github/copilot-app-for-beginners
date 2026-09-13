#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const UPSTREAM_REPOSITORY = "github/copilot-app-for-beginners";

const USAGE = `Set up GitHub Copilot app course training scenarios.

This script seeds a fork or disposable training repository with:
- course issue labels
- five seeded issues
- practice branches with intentional regressions
- pull requests for conversation-comment, failing-check, and merge-readiness lessons
- a PR comment for the empty-state copy review scenario

Run it from the repository root after you fork and clone the course repo.
GitHub changes target the repository configured as the local origin remote.

Usage:
  node .github/scripts/setup-training-scenarios.js --dry-run
  node .github/scripts/setup-training-scenarios.js --yes

Options:
  --dry-run                  Print the target and planned changes without making them.
  --yes                      Confirm changes to the displayed repository.
  --allow-shared-repository  Allow changes to a shared or upstream repository.
  --help                     Show this help.

Requirements:
  git, gh, Node.js
  gh auth login
`;

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const confirmed = args.includes("--yes");
const allowSharedRepository = args.includes("--allow-shared-repository");
if (process.argv.includes("--help") || process.argv.includes("-h")) {
  process.stdout.write(USAGE);
  process.exit(0);
}

const knownOptions = [
  "--dry-run",
  "--yes",
  "--allow-shared-repository",
  "--help",
  "-h",
];
const unknown = args.filter((arg) => !knownOptions.includes(arg));
if (unknown.length > 0) {
  console.error(`Unknown option: ${unknown[0]}`);
  process.stderr.write(USAGE);
  process.exit(1);
}

if (dryRun && confirmed) {
  console.error(
    "Use either --dry-run to preview or --yes to make changes, not both.",
  );
  process.exit(1);
}

function log(message) {
  console.error(message);
}

function commandExists(name) {
  const probe = process.platform === "win32" ? "where" : "which";
  const result = spawnSync(probe, [name], { encoding: "utf8" });
  return result.status === 0;
}

function parseGitHubRepository(remoteUrl) {
  const normalized = remoteUrl.trim().replace(/\.git$/i, "");
  const patterns = [
    /^https?:\/\/github\.com\/([^/]+)\/([^/]+)$/i,
    /^git@github\.com:([^/]+)\/([^/]+)$/i,
    /^ssh:\/\/git@github\.com\/([^/]+)\/([^/]+)$/i,
  ];

  for (const pattern of patterns) {
    const match = normalized.match(pattern);
    if (match) {
      return `${match[1]}/${match[2]}`;
    }
  }

  return "";
}

function run(file, args, options = {}) {
  const { allowFailure = false, quiet = false, ignoreDryRun = false } = options;

  if (dryRun && !ignoreDryRun) {
    log(`[dry-run] ${[file, ...args].join(" ")}`);
    return { status: 0, stdout: "", stderr: "" };
  }

  const result = spawnSync(file, args, {
    encoding: "utf8",
    stdio: quiet ? ["ignore", "pipe", "pipe"] : ["ignore", "pipe", "inherit"],
  });

  if (result.error) {
    throw result.error;
  }

  if (!allowFailure && result.status !== 0) {
    const detail = (result.stderr || result.stdout || "").trim();
    throw new Error(
      `${file} failed with exit code ${result.status}: ${args.join(" ")}${
        detail ? `\n${detail}` : ""
      }`,
    );
  }

  return {
    status: result.status ?? 1,
    stdout: (result.stdout || "").trim(),
    stderr: (result.stderr || "").trim(),
  };
}

function runOutput(file, args) {
  return run(file, args, { ignoreDryRun: true, quiet: true }).stdout;
}

function ghJson(args) {
  const stdout = runOutput("gh", args);
  if (!stdout) {
    return null;
  }
  return JSON.parse(stdout);
}

function writeTemp(text) {
  const filePath = path.join(
    os.tmpdir(),
    `copilot-app-setup-${process.pid}-${Date.now()}.md`,
  );
  fs.writeFileSync(filePath, text.endsWith("\n") ? text : `${text}\n`, "utf8");
  return filePath;
}

function replaceText(filePath, oldText, newText, scenario) {
  const original = fs.readFileSync(filePath, "utf8");
  if (original.includes(newText)) {
    return;
  }

  let nextOld = oldText;
  let nextNew = newText;
  if (!original.includes(nextOld)) {
    nextOld = oldText.replace(/\n/g, "\r\n");
    nextNew = newText.replace(/\n/g, "\r\n");
  }

  if (!original.includes(nextOld)) {
    throw new Error(
      `Expected text not found in ${filePath} for scenario ${scenario}`,
    );
  }

  fs.writeFileSync(filePath, original.replace(nextOld, nextNew), "utf8");
}

function addReadmeNote(filePath, marker, note) {
  const original = fs.readFileSync(filePath, "utf8");
  if (original.includes(marker)) {
    return;
  }

  const newline = original.includes("\r\n") ? "\r\n" : "\n";
  const normalizedNote = note.replace(/\n/g, newline);
  fs.writeFileSync(
    filePath,
    `${original.trimEnd()}${newline}${normalizedNote}${newline}`,
    "utf8",
  );
}

function applyScenario(scenario) {
  const app = "samples/book-app-web/src/App.tsx";
  const stats = "samples/book-app-web/src/components/ReadingStats.tsx";
  const sampleReadme = "samples/book-app-web/README.md";

  if (scenario === "search-case-bug") {
    replaceText(
      app,
      `const normalizedSearchTerm = filters.searchTerm.trim().toLowerCase();

  return bookList.filter((book) => {
    const matchesSearch =
      normalizedSearchTerm.length === 0 ||
      book.title.toLowerCase().includes(normalizedSearchTerm) ||
      book.author.toLowerCase().includes(normalizedSearchTerm);`,
      `const normalizedSearchTerm = filters.searchTerm.trim();

  return bookList.filter((book) => {
    const matchesSearch =
      normalizedSearchTerm.length === 0 ||
      book.title.includes(normalizedSearchTerm) ||
      book.author.includes(normalizedSearchTerm);`,
      scenario,
    );
    return;
  }

  if (scenario === "unread-count-bug") {
    replaceText(
      app,
      "<ReadingStats books={filteredBooks} />",
      "<ReadingStats books={books} />",
      scenario,
    );
    return;
  }

  if (scenario === "empty-state-regression") {
    replaceText(
      app,
      `<h2>No matching books found</h2>
            <p>Try a different search term, genre, or reading status.</p>`,
      `<h2>No results</h2>
            <p>Try again.</p>`,
      scenario,
    );
    return;
  }

  if (scenario === "empty-state-pr") {
    replaceText(
      app,
      `<h2>No matching books found</h2>
            <p>Try a different search term, genre, or reading status.</p>`,
      `<h2>No books found</h2>
            <p>Adjust your filters and try again.</p>`,
      scenario,
    );
    return;
  }

  if (scenario === "failing-stats-check") {
    replaceText(
      stats,
      "const favoriteCount = books.filter((book) => book.isFavorite).length;",
      "const favoriteCount = books.filter((book) => book.isFavorite && book.isRead).length;",
      scenario,
    );
    return;
  }

  if (scenario === "reading-dashboard-note") {
    addReadmeNote(
      sampleReadme,
      "## Training scenario note",
      `
## Training scenario note

This branch is used for the Agent Merge readiness discussion in the course. It keeps the app behavior stable while giving learners a safe pull request to inspect.
`,
    );
    return;
  }

  if (scenario === "card-polish-branch") {
    addReadmeNote(
      sampleReadme,
      "## Visual polish practice",
      `
## Visual polish practice

Use this branch to practice planning responsive card improvements before changing UI code.
`,
    );
    return;
  }

  throw new Error(`Unknown scenario: ${scenario}`);
}

function branchExistsRemote(branch) {
  return run("git", ["ls-remote", "--exit-code", "--heads", "origin", branch], {
    allowFailure: true,
    quiet: true,
    ignoreDryRun: true,
  }).status === 0;
}

function branchExistsLocal(branch) {
  return run(
    "git",
    ["show-ref", "--verify", "--quiet", `refs/heads/${branch}`],
    { allowFailure: true, quiet: true, ignoreDryRun: true },
  ).status === 0;
}

function ensureLabel(name, color, description) {
  if (dryRun) {
    log(`[dry-run] would ensure label: ${name}`);
    return;
  }

  const labels =
    ghJson(["label", "list", "--limit", "200", "--json", "name"]) || [];
  const exists = labels.some((label) => label.name === name);
  if (exists) {
    run("gh", [
      "label",
      "edit",
      name,
      "--color",
      color,
      "--description",
      description,
    ], { quiet: true, ignoreDryRun: true });
  } else {
    run("gh", [
      "label",
      "create",
      name,
      "--color",
      color,
      "--description",
      description,
    ], { quiet: true, ignoreDryRun: true });
  }
}

function ensureIssue(title, labelsCsv, body, githubUser) {
  if (!dryRun) {
    const issues = ghJson([
      "issue",
      "list",
      "--state",
      "all",
      "--limit",
      "200",
      "--json",
      "number,title",
    ]) || [];
    const existing = issues.find((issue) => issue.title === title);
    if (existing) {
      log(`Issue exists: #${existing.number} ${title}`);
      return;
    }
  }

  if (dryRun) {
    log(`[dry-run] would create issue: ${title}`);
    return;
  }

  const bodyFile = writeTemp(body);
  try {
    const args = [
      "issue",
      "create",
      "--title",
      title,
      "--body-file",
      bodyFile,
      "--assignee",
      githubUser,
    ];
    for (const label of labelsCsv.split(",")) {
      const trimmed = label.trim();
      if (trimmed) {
        args.push("--label", trimmed);
      }
    }
    run("gh", args, { quiet: true, ignoreDryRun: true });
    log(`Created issue: ${title}`);
  } finally {
    fs.rmSync(bodyFile, { force: true });
  }
}

function ensureBranch(branch, scenario, message, defaultBranch) {
  if (dryRun) {
    log(`[dry-run] would create or reuse branch: ${branch} (${scenario})`);
    return;
  }

  if (branchExistsRemote(branch)) {
    log(`Remote branch exists: ${branch}`);
    return;
  }

  if (branchExistsLocal(branch)) {
    log(`Local branch exists; pushing it: ${branch}`);
    run("git", ["switch", branch], { ignoreDryRun: true });
    run("git", ["push", "-u", "origin", branch], { ignoreDryRun: true });
    run("git", ["switch", defaultBranch], { ignoreDryRun: true });
    return;
  }

  run("git", ["switch", "-c", branch, `origin/${defaultBranch}`], {
    ignoreDryRun: true,
  });
  applyScenario(scenario);
  run("git", ["add", "samples/book-app-web"], { ignoreDryRun: true });

  const cached = run("git", ["diff", "--cached", "--quiet"], {
    allowFailure: true,
    quiet: true,
    ignoreDryRun: true,
  });
  if (cached.status === 0) {
    run("git", ["commit", "--allow-empty", "-m", message], {
      ignoreDryRun: true,
    });
  } else {
    run("git", ["commit", "-m", message], { ignoreDryRun: true });
  }

  run("git", ["push", "-u", "origin", branch], { ignoreDryRun: true });
  run("git", ["switch", defaultBranch], { ignoreDryRun: true });
  log(`Created branch: ${branch}`);
}

function ensurePr(branch, title, body, defaultBranch) {
  if (!dryRun) {
    const pulls = ghJson([
      "pr",
      "list",
      "--state",
      "all",
      "--head",
      branch,
      "--json",
      "number",
    ]) || [];
    if (pulls.length > 0) {
      log(`PR exists: #${pulls[0].number} ${title}`);
      return String(pulls[0].number);
    }
  }

  if (dryRun) {
    log(`[dry-run] would create PR from ${branch}: ${title}`);
    return "";
  }

  const bodyFile = writeTemp(body);
  try {
    const url = runOutput("gh", [
      "pr",
      "create",
      "--head",
      branch,
      "--base",
      defaultBranch,
      "--title",
      title,
      "--body-file",
      bodyFile,
    ]);
    const number = url.split("/").filter(Boolean).pop();
    log(`Created PR: #${number} ${title}`);
    return number || "";
  } finally {
    fs.rmSync(bodyFile, { force: true });
  }
}

function ensurePrComment(prNumber, marker, body) {
  if (!prNumber) {
    return;
  }

  if (dryRun) {
    log(`[dry-run] would add PR comment to #${prNumber}`);
    return;
  }

  const pr = ghJson([
    "pr",
    "view",
    prNumber,
    "--comments",
    "--json",
    "comments",
  ]);
  const exists = Boolean(
    pr && pr.comments &&
      pr.comments.some((comment) =>
        comment.body && comment.body.includes(marker)
      ),
  );
  if (exists) {
    log(`PR comment exists on #${prNumber}`);
    return;
  }

  run("gh", ["pr", "comment", prNumber, "--body", body], {
    quiet: true,
    ignoreDryRun: true,
  });
  log(`Added PR comment to #${prNumber}`);
}

function restoreStartingBranch(startBranch) {
  if (dryRun || !startBranch) {
    return null;
  }

  const currentResult = run("git", ["branch", "--show-current"], {
    allowFailure: true,
    quiet: true,
    ignoreDryRun: true,
  });
  const currentBranch = currentResult.stdout;

  if (currentResult.status === 0 && currentBranch === startBranch) {
    return null;
  }

  const restoreResult = run("git", ["switch", startBranch], {
    allowFailure: true,
    quiet: true,
    ignoreDryRun: true,
  });
  if (restoreResult.status === 0) {
    log(`Returned to starting branch: ${startBranch}`);
    return null;
  }

  log("");
  log(`Could not return to the starting branch "${startBranch}".`);
  log(`Current branch: ${currentBranch || "unknown"}`);
  if (restoreResult.stderr) {
    log(restoreResult.stderr);
  }
  log("Run git status, keep or resolve any remaining changes, then run:");
  log(`  git switch ${startBranch}`);
  return new Error(`Could not return to the starting branch "${startBranch}".`);
}

function main() {
  for (const name of ["git", "gh", "node"]) {
    if (!commandExists(name)) {
      throw new Error(`Missing required command: ${name}`);
    }
  }

  if (!fs.existsSync(".git")) {
    throw new Error(
      "Run this script from the root of a cloned Git repository.",
    );
  }

  if (!fs.existsSync("samples/book-app-web/src/App.tsx")) {
    throw new Error(
      "Could not find samples/book-app-web/src/App.tsx. Run from the course repository root.",
    );
  }

  const status = runOutput("git", ["status", "--porcelain"]);
  if (status) {
    throw new Error(
      "Your working tree has uncommitted changes. Commit, stash, or discard them before running this setup script.",
    );
  }

  if (!dryRun) {
    run("gh", ["auth", "status"], { quiet: true, ignoreDryRun: true });
  }

  const originUrl = runOutput("git", ["remote", "get-url", "origin"]);
  const originRepository = parseGitHubRepository(originUrl);
  if (!originRepository) {
    throw new Error(
      `Could not identify a GitHub repository from the origin remote: ${originUrl}`,
    );
  }

  const repoView = ghJson([
    "repo",
    "view",
    originRepository,
    "--json",
    "nameWithOwner,defaultBranchRef,hasIssuesEnabled",
  ]);
  const repo = repoView && repoView.nameWithOwner;
  const defaultBranch = repoView && repoView.defaultBranchRef &&
    repoView.defaultBranchRef.name;
  const startBranch = runOutput("git", ["branch", "--show-current"]);
  const githubUser = runOutput("gh", ["api", "user", "--jq", ".login"]);

  if (!repo || !defaultBranch) {
    throw new Error(
      "Could not determine the GitHub repository and its default branch.",
    );
  }

  process.env.GH_REPO = repo;

  if (!startBranch) {
    throw new Error(
      "The repository is in detached HEAD state. Switch to a branch, then run the setup again.",
    );
  }

  log(`Repository: ${repo}`);
  log(`Default branch: ${defaultBranch}`);

  if (!dryRun && !confirmed) {
    throw new Error(
      "No changes were made. Verify the repository above, preview with --dry-run, then rerun with --yes.",
    );
  }

  const repoOwner = repo.split("/")[0];
  const targetsUpstream =
    repo.toLowerCase() === UPSTREAM_REPOSITORY.toLowerCase();
  const targetsSharedRepository =
    repoOwner.toLowerCase() !== githubUser.toLowerCase();
  if (
    !dryRun && (targetsUpstream || targetsSharedRepository) &&
    !allowSharedRepository
  ) {
    throw new Error(
      `Refusing to change shared or upstream repository "${repo}". Use your own fork, or add --allow-shared-repository with --yes only when this target is intentional.`,
    );
  }

  const workflows = ghJson([
    "workflow",
    "list",
    "--all",
    "--json",
    "name,path,state",
  ]) || [];
  const bookAppWorkflowActive = workflows.some((workflow) =>
    workflow.path === ".github/workflows/book-app-web.yml" &&
    workflow.state === "active"
  );

  if (!bookAppWorkflowActive) {
    const actionsUrl = `https://github.com/${repo}/actions`;
    if (dryRun) {
      log(
        `[dry-run] GitHub Actions is not active. Enable workflows at ${actionsUrl} before running with --yes.`,
      );
    } else {
      throw new Error(
        `The Book app web workflow is not active. Open ${actionsUrl}, enable workflows for the fork, then rerun the setup script.`,
      );
    }
  }

  let setupError = null;
  try {
    if (repoView.hasIssuesEnabled === false) {
      if (dryRun) {
        log("[dry-run] would enable GitHub Issues");
      } else {
        log("Enabling GitHub Issues...");
        run("gh", ["repo", "edit", repo, "--enable-issues"], {
          ignoreDryRun: true,
        });
      }
    }

    if (dryRun) {
      log(`[dry-run] would fetch and update ${defaultBranch}`);
    } else {
      run("git", ["fetch", "origin", defaultBranch], { ignoreDryRun: true });
      run("git", ["switch", defaultBranch], { ignoreDryRun: true });
      run("git", ["pull", "--ff-only", "origin", defaultBranch], {
        ignoreDryRun: true,
      });
    }

    log("Ensuring labels...");
    ensureLabel("book-app-web", "1f883d", "Course sample app scenario");
    ensureLabel("good first issue", "7057ff", "Beginner-friendly course issue");
    ensureLabel("bug", "d73a4a", "Intentional course bug scenario");
    ensureLabel("tests", "0052cc", "Testing or CI scenario");
    ensureLabel("accessibility", "0e8a16", "Accessibility-focused scenario");
    ensureLabel("copy", "5319e7", "Content or copy scenario");
    ensureLabel("ui", "c2e0c6", "User interface scenario");
    ensureLabel("responsive", "bfd4f2", "Responsive layout scenario");
    ensureLabel("ci", "fbca04", "Continuous integration scenario");

    log("Ensuring issues...");
    ensureIssue(
      "Make search case-insensitive",
      "bug,good first issue,book-app-web",
      `The book search should match titles and authors regardless of letter case.

Training branch: \`practice-search-case-bug\`

Repro:
1. Open \`samples/book-app-web\`.
2. Run \`npm run dev\`.
3. Search for \`hobbit\`.

Expected result: \`The Hobbit\` appears in the results.

Learner goal: Ask Copilot to find the search logic, write or update a test, and make the smallest safe fix.`,
      githubUser,
    );

    ensureIssue(
      "Keep unread stats correct when filters are active",
      "bug,tests,book-app-web",
      `Stats should describe the books currently shown after filters are applied.

Training branch: \`practice-unread-count-bug\`

Repro:
1. Filter status to \`Unread\`.
2. Compare the book cards with the stats row.

Expected result: The unread count matches the visible unread cards.

Learner goal: Ask Copilot to trace props from \`App.tsx\` to \`ReadingStats.tsx\`.`,
      githubUser,
    );

    ensureIssue(
      "Improve the empty state copy",
      "accessibility,copy,book-app-web",
      `The empty state should be clear for beginners and screen reader users.

Training branch: \`practice-empty-state-copy\`

Repro:
1. Search for text that matches no books.
2. Review the empty state.

Expected result: The message explains that no matching books were found and suggests changing filters.

Learner goal: Use a PR conversation comment to request clearer copy, then ask Copilot to address the comment.`,
      githubUser,
    );

    ensureIssue(
      "Polish book card spacing and responsive layout",
      "ui,responsive,book-app-web",
      `Book cards should have clear hierarchy, comfortable spacing, and a useful mobile layout.

Training branch: \`practice-card-polish\`

Repro:
1. Open the app in the browser.
2. Resize the viewport below 560px.
3. Inspect the card spacing and status labels.

Expected result: Cards stay readable and controls remain easy to use.

Learner goal: Use browser validation or a Pick and Polish exercise to compare visual changes before accepting them.`,
      githubUser,
    );

    ensureIssue(
      "Simulate a failing stats test for CI practice",
      "ci,tests,book-app-web",
      `The default app should pass tests. This scenario creates a training branch that changes favorite counting incorrectly so CI fails on the stats test.

Training branch and PR: \`practice-failing-stats-check\`

Expected failure: \`npm test -- --run\` fails in \`src/tests/stats.test.tsx\` because unread favorites are valid favorites too.

Learner goal: Use Copilot to inspect the failing check, explain the regression, and restore the correct favorite count.`,
      githubUser,
    );

    log("Ensuring practice branches...");
    ensureBranch(
      "practice-search-case-bug",
      "search-case-bug",
      "Seed search case practice bug",
      defaultBranch,
    );
    ensureBranch(
      "practice-unread-count-bug",
      "unread-count-bug",
      "Seed unread stats practice bug",
      defaultBranch,
    );
    ensureBranch(
      "practice-empty-state-copy",
      "empty-state-regression",
      "Seed empty-state copy practice",
      defaultBranch,
    );
    ensureBranch(
      "practice-card-polish",
      "card-polish-branch",
      "Seed card polish practice branch",
      defaultBranch,
    );
    ensureBranch(
      "practice-failing-stats-check",
      "failing-stats-check",
      "Seed failing stats check practice",
      defaultBranch,
    );
    ensureBranch(
      "fix-empty-state-copy",
      "empty-state-pr",
      "Draft empty-state copy PR scenario",
      defaultBranch,
    );
    ensureBranch(
      "feature-reading-dashboard",
      "reading-dashboard-note",
      "Draft merge-readiness PR scenario",
      defaultBranch,
    );

    log("Ensuring pull requests...");
    const emptyPr = ensurePr(
      "fix-empty-state-copy",
      "Improve empty-state copy",
      `This PR updates the empty state shown when filters match no books.

Course use:
- Practice responding to a PR conversation comment.
- Ask Copilot for the smallest safe improvement.
- Inspect the diff before accepting changes.`,
      defaultBranch,
    );

    ensurePr(
      "practice-failing-stats-check",
      "Failing stats check practice",
      `This PR intentionally changes stats logic so CI can demonstrate a failing check.

Expected course behavior:
- \`npm test -- --run\` fails in \`src/tests/stats.test.tsx\`.
- Learners ask Copilot to explain the failure and restore the correct favorite count.`,
      defaultBranch,
    );

    ensurePr(
      "feature-reading-dashboard",
      "Reading dashboard merge-readiness practice",
      `This PR is a safe merge-readiness discussion scenario.

Course use:
- Confirm tests and build pass.
- Discuss review state and branch protection.
- Decide whether Agent Merge would be appropriate after human review.`,
      defaultBranch,
    );

    ensurePrComment(
      emptyPr,
      "Please mention that they can change the search term, genre, or reading status.",
      "The copy is better, but can we make it more helpful for a first-time learner? Please mention that they can change the search term, genre, or reading status.",
    );
  } catch (error) {
    setupError = error;
    throw error;
  } finally {
    const restorationError = restoreStartingBranch(startBranch);
    if (restorationError && !setupError) {
      throw restorationError;
    }
  }

  log("");
  log("Setup complete.");
  log("Next checks:");
  log(
    "- Open the GitHub Copilot app and connect this fork/training repository.",
  );
  log("- Confirm the seeded issues and PRs appear in My work.");
  log(
    "- Wait for the failing-check PR workflow to finish before using that lesson.",
  );
}

try {
  main();
} catch (error) {
  console.error("");
  console.error(
    `Setup failed: ${error instanceof Error ? error.message : String(error)}`,
  );
  process.exitCode = 1;
}
