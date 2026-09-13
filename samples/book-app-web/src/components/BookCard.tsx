import React from "react";
import type { Book } from "../data/books";

type BookCardProps = {
  book: Book;
};

export function BookCard({ book }: BookCardProps) {
  return (
    <article className="book-card" aria-label={`${book.title} by ${book.author}`}>
      <div className="book-card__header">
        <div>
          <p className="book-card__genre">{book.genre}</p>
          <h2>{book.title}</h2>
        </div>
        {book.isFavorite && (
          <span className="book-card__favorite" aria-label="Favorite book">
            ★
          </span>
        )}
      </div>
      <p className="book-card__author">by {book.author}</p>
      <div className="book-card__meta">
        <span>{book.rating}/5 rating</span>
        <span className={book.isRead ? "status status--read" : "status status--unread"}>
          {book.isRead ? "Read" : "Unread"}
        </span>
      </div>
    </article>
  );
}
