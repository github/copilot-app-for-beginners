# GitHub Copilot instructions

Use these instructions when working in this repository.

This is a beginner course repo for the GitHub Copilot app. The canonical sample is `samples/book-app-web`: a frontend-only book collection used to practice review, tests, browser preview, issues, and pull requests.

Do not edit chapter README files unless the user asks for chapter content changes. Keep changes small and beginner-readable.

## Sample app

`samples/book-app-web` is a Vite, React, TypeScript, and Vitest app. It has no backend, database, or external API. Do not add those.

The UI lets learners search books by title or author, filter by genre and reading status, and inspect reading stats for the books currently shown.

Keep the stack as-is. Prefer small React components with clear props. Keep seed data in `src/data/books.ts` and CSS in `src/styles/app.css`. Use accessible labels for filters, regions, and empty states.

Typical files:

- `src/App.tsx`: filter state and `filterBooks`
- `src/components/BookCard.tsx`, `BookFilters.tsx`, `ReadingStats.tsx`
- `src/data/books.ts`: seed data
- `src/styles/app.css`
- `src/tests/filtering.test.tsx`, `src/tests/stats.test.tsx`

Default behavior to preserve unless a training scenario says otherwise:

- Search matches title and author without depending on letter case.
- Reading stats (total, read, unread, favorites, average rating) come from the books currently shown after filters, not the unfiltered list.
- Favorite count includes unread favorites.
- Empty-state copy should mention changing the search term, genre, or reading status.

Use the current Node.js LTS. The app declares `engines.node` as `^20.19.0 || >=22.12.0`. CI uses Node 22.

## Validation

Always work from `samples/book-app-web`. If `node_modules` is missing (including in a new worktree), run `npm install` first.

```bash
npm install
npm test -- --run
npm run build
npm run dev -- --host 127.0.0.1 --port 5173
```

- `npm test -- --run` runs Vitest once and exits. Pass `--run` through npm so Vitest does not stay in watch mode.
- `npm run build` typechecks with `tsc --noEmit`, then builds with Vite.
- Browser preview is `http://127.0.0.1:5173`. Confirm filter, stats, and empty-state behavior there, not only in chat.

CI for this sample is `.github/workflows/book-app-web.yml` (`Book app web`). It runs `npm ci`, `npm test -- --run`, and `npm run build` on pull requests that touch the sample.

## Course scenarios

The default app on `main` should pass tests and build cleanly.

Keep intentional failing behavior in training branches or in `samples/app-course-issues.md` and `samples/app-course-pr-scenarios.md`, not in the default app.

When fixing a scenario, prefer adding or preserving a focused test before changing app logic. Do not weaken a failing test to make CI pass.
