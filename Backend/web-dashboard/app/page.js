"use client";

import { useState, useEffect } from "react";
import MovieGrid from "../components/MovieGrid";
import StatsCards from "../components/StatsCards";
import { getTrending, getNowPlaying, getTraktTrending } from "../lib/api";

export default function Dashboard() {
  const [trending, setTrending] = useState([]);
  const [nowPlaying, setNowPlaying] = useState([]);
  const [traktTrending, setTraktTrending] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      try {
        const [t, np, tt] = await Promise.allSettled([
          getTrending(),
          getNowPlaying(),
          getTraktTrending(),
        ]);
        if (t.status === "fulfilled") setTrending(t.value || []);
        if (np.status === "fulfilled") setNowPlaying(np.value || []);
        if (tt.status === "fulfilled") setTraktTrending(tt.value || []);
      } catch (err) {
        console.error("Failed to load dashboard data:", err);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4" />
          <p className="text-gray-500">Loading box office data...</p>
        </div>
      </div>
    );
  }

  const allMovies = [...trending, ...nowPlaying, ...traktTrending];

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Dashboard</h1>
        <p className="text-gray-500">
          Real-time box office analytics — same Firebase source of truth as the iOS app.
        </p>
      </div>

      <StatsCards movies={allMovies} />

      <MovieGrid title="🔥 Trending This Week (TMDB)" movies={trending.slice(0, 12)} />
      <MovieGrid title="🎬 Now Playing in Theaters" movies={nowPlaying.slice(0, 12)} />
      <MovieGrid title="📈 Trakt Trending" movies={traktTrending.slice(0, 12)} />
    </div>
  );
}
