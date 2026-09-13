---
name: book-app-reviewer
description: Review changes in samples/book-app-web for accessibility, responsive layout, tests/build validation, and small beginner-safe changes.
---

# Book App Reviewer

Use this skill to review changes in `samples/book-app-web`.

## Review focus

1. Confirm the app remains Vite, React, TypeScript, and Vitest only.
2. Check that tests still pass with `npm test -- --run`.
3. Check that the app builds with `npm run build`.
4. Review accessibility for labels, region names, keyboard-friendly controls, and useful empty states.
5. Review responsive behavior for the filter row, stats cards, and book card grid.
6. Keep changes small enough for a beginner to understand in a course chapter.

## Preferred feedback style

- Explain what matters and why.
- Avoid style-only comments unless they affect readability, accessibility, or the course goal.
- Suggest the smallest safe fix.
- If a scenario intentionally fails, confirm it is documented in `samples/app-course-pr-scenarios.md` or `samples/app-course-issues.md`.

## Files usually in scope

- `samples/book-app-web/src/App.tsx`
- `samples/book-app-web/src/components/*.tsx`
- `samples/book-app-web/src/data/books.ts`
- `samples/book-app-web/src/styles/app.css`
- `samples/book-app-web/src/tests/*.tsx`
