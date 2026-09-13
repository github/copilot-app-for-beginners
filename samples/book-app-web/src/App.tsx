import React from "react";
import { useMemo, useState } from "react";
import { BookCard } from "./components/BookCard";
import { BookFilters } from "./components/BookFilters";
import { ReadingStats } from "./components/ReadingStats";
import { books, type Book } from "./data/books";
import "./styles/app.css";

export type ReadingStatus = "all" | "read" | "unread";

export type BookFiltersState = {
  searchTerm: string;
  selectedGenre: string;
  readingStatus: ReadingStatus;
};

const defaultFilters: BookFiltersState = {
  searchTerm: "",
  selectedGenre: "all",
  readingStatus: "all"
};

export function filterBooks(bookList: Book[], filters: BookFiltersState) {
  const normalizedSearchTerm = filters.searchTerm.trim().toLowerCase();

  return bookList.filter((book) => {
    const matchesSearch =
      normalizedSearchTerm.length === 0 ||
      book.title.toLowerCase().includes(normalizedSearchTerm) ||
      book.author.toLowerCase().includes(normalizedSearchTerm);
    const matchesGenre = filters.selectedGenre === "all" || book.genre === filters.selectedGenre;
    const matchesStatus =
      filters.readingStatus === "all" ||
      (filters.readingStatus === "read" && book.isRead) ||
      (filters.readingStatus === "unread" && !book.isRead);

    return matchesSearch && matchesGenre && matchesStatus;
  });
}

export default function App() {
  const [filters, setFilters] = useState<BookFiltersState>(defaultFilters);
  const genres = useMemo(() => [...new Set(books.map((book) => book.genre))].sort(), []);
  const filteredBooks = useMemo(() => filterBooks(books, filters), [filters]);

  return (
    <main className="app-shell">
      <section className="hero">
        <p className="eyebrow">GitHub Copilot app sample</p>
        <h1>Book Collection</h1>
        <p>
          Explore a small reading list used throughout the course to practice issues, pull
          requests, review comments, tests, and browser validation.
        </p>
      </section>

      <ReadingStats books={filteredBooks} />

      <BookFilters
        genres={genres}
        searchTerm={filters.searchTerm}
        selectedGenre={filters.selectedGenre}
        readingStatus={filters.readingStatus}
        onSearchTermChange={(searchTerm) => setFilters((current) => ({ ...current, searchTerm }))}
        onGenreChange={(selectedGenre) => setFilters((current) => ({ ...current, selectedGenre }))}
        onReadingStatusChange={(readingStatus) =>
          setFilters((current) => ({ ...current, readingStatus }))
        }
      />

      <section className="book-results" aria-live="polite">
        <div className="results-heading">
          <h2>{filteredBooks.length} books shown</h2>
          <p>Stats update as filters change so learners can validate behavior quickly.</p>
        </div>

        {filteredBooks.length > 0 ? (
          <div className="book-grid">
            {filteredBooks.map((book) => (
              <BookCard key={book.id} book={book} />
            ))}
          </div>
        ) : (
          <div className="empty-state" role="status">
            <h2>No matching books found</h2>
            <p>Try a different search term, genre, or reading status.</p>
          </div>
        )}
      </section>
    </main>
  );
}
