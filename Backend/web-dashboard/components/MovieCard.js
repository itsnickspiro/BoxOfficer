"use client";

export default function MovieCard({ movie }) {
  const posterUrl = movie.poster_path
    ? `https://image.tmdb.org/t/p/w300${movie.poster_path}`
    : null;

  const rating = movie.vote_average ? movie.vote_average.toFixed(1) : "N/A";

  return (
    <div className="bg-white dark:bg-[#1c1c1e] rounded-xl shadow-sm overflow-hidden hover:shadow-lg transition group">
      <div className="relative aspect-[2/3] bg-gray-200 dark:bg-gray-800">
        {posterUrl ? (
          <img
            src={posterUrl}
            alt={movie.title}
            className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
            loading="lazy"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-gray-400 text-4xl">
            🎬
          </div>
        )}
        <div className="absolute top-2 right-2 bg-black/70 text-white text-xs font-bold px-2 py-1 rounded-full">
          ⭐ {rating}
        </div>
      </div>
      <div className="p-3">
        <h3 className="font-semibold text-sm truncate">{movie.title}</h3>
        {movie.release_date && (
          <p className="text-xs text-gray-500 mt-1">
            {new Date(movie.release_date).toLocaleDateString("en-US", {
              year: "numeric",
              month: "short",
              day: "numeric",
            })}
          </p>
        )}
        {movie.revenue > 0 && (
          <p className="text-xs text-green-600 dark:text-green-400 font-medium mt-1">
            💰 ${(movie.revenue / 1_000_000).toFixed(1)}M
          </p>
        )}
      </div>
    </div>
  );
}
