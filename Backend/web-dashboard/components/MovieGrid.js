"use client";

import MovieCard from "./MovieCard";

export default function MovieGrid({ title, movies }) {
  if (!movies || movies.length === 0) {
    return (
      <section className="mb-10">
        <h2 className="text-xl font-bold mb-4">{title}</h2>
        <p className="text-gray-500">No data available yet. Deploy Cloud Functions to populate.</p>
      </section>
    );
  }

  return (
    <section className="mb-10">
      <h2 className="text-xl font-bold mb-4">{title}</h2>
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
        {movies.map((movie) => (
          <MovieCard key={movie.id} movie={movie} />
        ))}
      </div>
    </section>
  );
}
