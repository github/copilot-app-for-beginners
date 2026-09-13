import React from "react";
import type { Book } from "../data/books";

type ReadingStatsProps = {
  books: Book[];
};

export function getReadingStats(books: Book[]) {
  const readCount = books.filter((book) => book.isRead).length;
  const favoriteCount = books.filter((book) => book.isFavorite).length;
  const ratingTotal = books.reduce((total, book) => total + book.rating, 0);

  return {
    totalCount: books.length,
    readCount,
    unreadCount: books.length - readCount,
    favoriteCount,
    averageRating: books.length === 0 ? 0 : ratingTotal / books.length
  };
}

export function ReadingStats({ books }: ReadingStatsProps) {
  const stats = getReadingStats(books);

  return (
    <section className="stats-panel" aria-label="Reading stats">
      <dl className="stats">
        <StatCard label="Total" value={stats.totalCount.toString()} />
        <StatCard label="Read" value={stats.readCount.toString()} />
        <StatCard label="Unread" value={stats.unreadCount.toString()} />
        <StatCard label="Favorites" value={stats.favoriteCount.toString()} />
        <StatCard label="Average rating" value={stats.averageRating.toFixed(1)} />
      </dl>
    </section>
  );
}

type StatCardProps = {
  label: string;
  value: string;
};

function StatCard({ label, value }: StatCardProps) {
  return (
    <div className="stat-card" aria-label={`${label}: ${value}`}>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}
