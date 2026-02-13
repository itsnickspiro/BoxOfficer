"use client";

import { useState } from "react";
import MovieGrid from "../../components/MovieGrid";
import { searchMovies } from "../../lib/api";

export default function SearchPage() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  async function handleSearch(e) {
    e.preventDefault();
    if (!query.trim()) return;
    setLoading(true);
    setSearched(true);
    try {
      const movies = await searchMovies(query.trim());
      setResults(movies || []);
    } catch (err) {
      console.error("Search failed:", err);
      setResults([]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h1 className="text-3xl font-bold mb-6">Search Movies</h1>

      <form onSubmit={handleSearch} className="mb-8 flex gap-3">
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search for any movie..."
          className="flex-1 px-4 py-3 rounded-xl bg-white dark:bg-[#1c1c1e] border border-gray-200 dark:border-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 text-base"
        />
        <button
          type="submit"
          disabled={loading}
          className="px-6 py-3 bg-blue-500 text-white rounded-xl font-medium hover:bg-blue-600 transition disabled:opacity-50"
        >
          {loading ? "Searching..." : "Search"}
        </button>
      </form>

      {loading && (
        <div className="flex justify-center py-12">
          <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-500" />
        </div>
      )}

      {searched && !loading && (
        <MovieGrid
          title={`Results for "${query}" (${results.length})`}
          movies={results}
        />
      )}

      {!searched && (
        <div className="text-center py-20 text-gray-400">
          <p className="text-5xl mb-4">🔍</p>
          <p>Search for movies by title to see box office data and analytics.</p>
        </div>
      )}
    </div>
  );
}
