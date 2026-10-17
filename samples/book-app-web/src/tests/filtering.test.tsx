import { afterEach, describe, expect, it } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { filterBooks, type BookFiltersState } from "../App";
import App from "../App";
import { books } from "../data/books";

afterEach(cleanup);

const defaultFilters: BookFiltersState = {
  searchTerm: "",
  selectedGenre: "all",
  readingStatus: "all"
};

describe("filterBooks", () => {
  it("matches title and author searches without depending on letter case", () => {
    const results = filterBooks(books, {
      ...defaultFilters,
      searchTerm: "hobbit"
    });

    expect(results.map((book) => book.title)).toEqual(["The Hobbit"]);
  });

  it("filters by genre and reading status together", () => {
    const results = filterBooks(books, {
      ...defaultFilters,
      selectedGenre: "Fantasy",
      readingStatus: "unread"
    });

    expect(results.map((book) => book.title)).toEqual(["The Night Circus"]);
  });
});

describe("Book Collection filters", () => {
  it("shows Clear filters only when a filter differs from its default", async () => {
    const user = userEvent.setup();
    render(<App />);

    expect(screen.queryByRole("button", { name: "Clear filters" })).toBeNull();

    await user.selectOptions(screen.getByLabelText("Genre"), "Fantasy");
    expect(screen.getByRole("button", { name: "Clear filters" })).toBeTruthy();

    await user.click(screen.getByRole("button", { name: "Clear filters" }));
    expect(screen.queryByRole("button", { name: "Clear filters" })).toBeNull();

    await user.selectOptions(screen.getByLabelText("Status"), "read");
    expect(screen.getByRole("button", { name: "Clear filters" })).toBeTruthy();

    await user.click(screen.getByRole("button", { name: "Clear filters" }));
    await user.type(screen.getByLabelText("Search"), "Hobbit");
    expect(screen.getByRole("button", { name: "Clear filters" })).toBeTruthy();
  });

  it("does not show Clear filters when search contains only whitespace", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.type(screen.getByLabelText("Search"), "   ");
    expect(screen.queryByRole("button", { name: "Clear filters" })).toBeNull();
  });

  it("resets all filters and restores the full book list and reading stats", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.type(screen.getByLabelText("Search"), "Hobbit");
    await user.selectOptions(screen.getByLabelText("Genre"), "Fantasy");
    await user.selectOptions(screen.getByLabelText("Status"), "read");

    expect(screen.getByRole("heading", { name: "1 books shown" })).toBeTruthy();
    expect(screen.getByLabelText("Total: 1")).toBeTruthy();

    await user.click(screen.getByRole("button", { name: "Clear filters" }));

    expect((screen.getByLabelText("Search") as HTMLInputElement).value).toBe("");
    expect((screen.getByLabelText("Genre") as HTMLSelectElement).value).toBe("all");
    expect((screen.getByLabelText("Status") as HTMLSelectElement).value).toBe("all");
    expect(screen.queryByRole("button", { name: "Clear filters" })).toBeNull();
    expect(screen.getByRole("heading", { name: "12 books shown" })).toBeTruthy();
    expect(screen.getByLabelText("Total: 12")).toBeTruthy();
  });
});
