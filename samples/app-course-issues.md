# Book App Web Course Issues

Use these issue drafts for app sessions, branch practice, and guided fixes. The sample app is stable by default, so each bug scenario includes a small regression setup step. Add the regression on a training branch, then let Copilot diagnose and fix it.

## Issue 1: Make search case-insensitive

Labels: `bug`, `good first issue`, `book-app-web`

The book search should match titles and authors regardless of letter case.

### Training branch setup

Create a branch named `practice-search-case-bug`, then introduce the regression in `samples/book-app-web/src/App.tsx`:

```diff
- const normalizedSearchTerm = filters.searchTerm.trim().toLowerCase();
+ const normalizedSearchTerm = filters.searchTerm.trim();

  return bookList.filter((book) => {
    const matchesSearch =
      normalizedSearchTerm.length === 0 ||
-     book.title.toLowerCase().includes(normalizedSearchTerm) ||
-     book.author.toLowerCase().includes(normalizedSearchTerm);
+     book.title.includes(normalizedSearchTerm) ||
+     book.author.includes(normalizedSearchTerm);
```

### Repro steps

1. Open `samples/book-app-web`.
2. Run `npm run dev`.
3. Search for `hobbit`.

### Expected result

`The Hobbit` appears in the results.

### Learner goal

Ask Copilot to find the search logic, write or update a test, and make the smallest safe fix.

## Issue 2: Keep unread stats correct when filters are active

Labels: `bug`, `tests`, `book-app-web`

Stats should describe the books currently shown after filters are applied.

### Training branch setup

Create a branch named `practice-unread-count-bug`, then introduce the regression in `samples/book-app-web/src/App.tsx`:

```diff
- <ReadingStats books={filteredBooks} />
+ <ReadingStats books={books} />
```

This makes the stats ignore active filters.

### Repro steps

1. Filter status to `Unread`.
2. Compare the book cards with the stats row.

### Expected result

The unread count matches the visible unread cards.

### Learner goal

Practice asking Copilot to trace props from `App.tsx` to `ReadingStats.tsx`.

## Issue 3: Improve the empty state copy

Labels: `accessibility`, `copy`, `book-app-web`

The empty state should be clear for beginners and screen reader users.

### Training branch setup

Create a branch named `practice-empty-state-copy`, then make the empty state less helpful in `samples/book-app-web/src/App.tsx`:

```diff
- <h2>No matching books found</h2>
- <p>Try a different search term, genre, or reading status.</p>
+ <h2>No results</h2>
+ <p>Try again.</p>
```

### Repro steps

1. Search for text that matches no books.
2. Review the empty state.

### Expected result

The message explains that no matching books were found and suggests changing filters.

### Learner goal

Use a PR conversation comment to request clearer copy, then ask Copilot to address the comment.

## Issue 4: Polish book card spacing and responsive layout

Labels: `ui`, `responsive`, `book-app-web`

Book cards should have clear hierarchy, comfortable spacing, and a useful mobile layout.

### Training branch setup

Create a branch named `practice-card-polish`, then use the default app as the baseline. This is a visual improvement scenario, not a failing-test bug. The setup script may add a harmless README note so the branch can be opened as a training PR.

### Repro steps

1. Open the app in the browser.
2. Resize the viewport below 560px.
3. Inspect the card spacing and status labels.

### Expected result

Cards stay readable and controls remain easy to use.

### Learner goal

Use browser validation or a Pick and Polish exercise to compare visual changes before accepting them.

## Issue 5: Simulate a failing stats test for CI practice

Labels: `ci`, `tests`, `book-app-web`

The default app should pass tests. For this scenario, create a training branch that changes favorite counting incorrectly, then let CI fail on the stats test.

### Suggested intentional regression

Change the favorite count to count only read favorites. That should make the seeded `stats.test.tsx` expectation fail because unread favorites are valid favorites too.

Apply this change in `samples/book-app-web/src/components/ReadingStats.tsx`:

```diff
- const favoriteCount = books.filter((book) => book.isFavorite).length;
+ const favoriteCount = books.filter((book) => book.isFavorite && book.isRead).length;
```

### Learner goal

Practice using Copilot to inspect a failing check, explain the regression, and restore the correct favorite count.
