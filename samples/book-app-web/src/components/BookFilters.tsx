import React from "react";
import type { ReadingStatus } from "../App";

type BookFiltersProps = {
  genres: string[];
  searchTerm: string;
  selectedGenre: string;
  readingStatus: ReadingStatus;
  onSearchTermChange: (value: string) => void;
  onGenreChange: (value: string) => void;
  onReadingStatusChange: (value: ReadingStatus) => void;
};

export function BookFilters({
  genres,
  searchTerm,
  selectedGenre,
  readingStatus,
  onSearchTermChange,
  onGenreChange,
  onReadingStatusChange
}: BookFiltersProps) {
  return (
    <section className="filters" aria-label="Book filters">
      <label>
        Search
        <input
          type="search"
          value={searchTerm}
          placeholder="Search by title or author"
          onChange={(event) => onSearchTermChange(event.target.value)}
        />
      </label>

      <label>
        Genre
        <select value={selectedGenre} onChange={(event) => onGenreChange(event.target.value)}>
          <option value="all">All genres</option>
          {genres.map((genre) => (
            <option key={genre} value={genre}>
              {genre}
            </option>
          ))}
        </select>
      </label>

      <label>
        Status
        <select
          value={readingStatus}
          onChange={(event) => onReadingStatusChange(event.target.value as ReadingStatus)}
        >
          <option value="all">All books</option>
          <option value="read">Read</option>
          <option value="unread">Unread</option>
        </select>
      </label>
    </section>
  );
}
