# Book App Web

This is the canonical sample app for the GitHub Copilot app for Beginners course.

It is intentionally small so learners can focus on app workflows instead of backend setup. The app uses Vite, React, TypeScript, and Vitest.

## Run the app

Use the current Node.js LTS.

```bash
npm install
npm run dev -- --host 127.0.0.1 --port 5173
```

## Validate changes

```bash
npm test -- --run
npm run build
```

## Course scenarios

The app starts in a stable state. Tests should pass by default.

The course still needs predictable issue and PR practice, so seeded scenario text lives in:

- `../app-course-issues.md`
- `../app-course-pr-scenarios.md`

Those files describe bugs learners can introduce or fix in a branch without making the default sample fail.
