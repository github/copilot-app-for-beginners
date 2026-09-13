export type Book = {
  id: number;
  title: string;
  author: string;
  genre: string;
  rating: number;
  isRead: boolean;
  isFavorite: boolean;
};

export const books: Book[] = [
  {
    id: 1,
    title: "The Hobbit",
    author: "J.R.R. Tolkien",
    genre: "Fantasy",
    rating: 5,
    isRead: true,
    isFavorite: true
  },
  {
    id: 2,
    title: "A Wizard of Earthsea",
    author: "Ursula K. Le Guin",
    genre: "Fantasy",
    rating: 5,
    isRead: true,
    isFavorite: true
  },
  {
    id: 3,
    title: "Kindred",
    author: "Octavia E. Butler",
    genre: "Science Fiction",
    rating: 5,
    isRead: true,
    isFavorite: true
  },
  {
    id: 4,
    title: "Project Hail Mary",
    author: "Andy Weir",
    genre: "Science Fiction",
    rating: 4,
    isRead: false,
    isFavorite: false
  },
  {
    id: 5,
    title: "The Thursday Murder Club",
    author: "Richard Osman",
    genre: "Mystery",
    rating: 4,
    isRead: true,
    isFavorite: false
  },
  {
    id: 6,
    title: "The Book Thief",
    author: "Markus Zusak",
    genre: "Historical Fiction",
    rating: 5,
    isRead: true,
    isFavorite: true
  },
  {
    id: 7,
    title: "Atomic Habits",
    author: "James Clear",
    genre: "Nonfiction",
    rating: 4,
    isRead: false,
    isFavorite: false
  },
  {
    id: 8,
    title: "Braiding Sweetgrass",
    author: "Robin Wall Kimmerer",
    genre: "Nonfiction",
    rating: 5,
    isRead: false,
    isFavorite: true
  },
  {
    id: 9,
    title: "The Night Circus",
    author: "Erin Morgenstern",
    genre: "Fantasy",
    rating: 4,
    isRead: false,
    isFavorite: false
  },
  {
    id: 10,
    title: "Mexican Gothic",
    author: "Silvia Moreno-Garcia",
    genre: "Horror",
    rating: 4,
    isRead: true,
    isFavorite: false
  },
  {
    id: 11,
    title: "Tomorrow, and Tomorrow, and Tomorrow",
    author: "Gabrielle Zevin",
    genre: "Literary Fiction",
    rating: 4,
    isRead: false,
    isFavorite: true
  },
  {
    id: 12,
    title: "The House in the Cerulean Sea",
    author: "TJ Klune",
    genre: "Fantasy",
    rating: 5,
    isRead: true,
    isFavorite: true
  }
];
