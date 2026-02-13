"use client";

import { useState, useEffect } from "react";
import MovieGrid from "../../components/MovieGrid";
import { getTrending, getTraktTrending, getTopRated, getTopGrossing } from "../../lib/api";

export default function TrendingPage() {
  const [data, setData] = useState({
    trending: [],
    traktTrending: [],
    topRated: [],
    topGrossing: [],
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const [t, tt, tr, tg] = await Promise.allSettled([
          getTrending(),
          getTraktTrending(),
          getTopRated("US", 1),
          getTopGrossing(1),
        ]);
        setData({
          trending: t.status === "fulfilled" ? t.value : [],
          traktTrending: tt.status === "fulfilled" ? tt.value : [],
          topRated: tr.status === "fulfilled" ? tr.value : [],
          topGrossing: tg.status === "fulfilled" ? tg.value : [],
        });
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto" />
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-3xl font-bold mb-6">Trending & Top Charts</h1>
      <MovieGrid title="🔥 TMDB Trending" movies={data.trending.slice(0, 18)} />
      <MovieGrid title="📈 Trakt Trending" movies={data.traktTrending.slice(0, 18)} />
      <MovieGrid title="⭐ Top Rated" movies={data.topRated.slice(0, 18)} />
      <MovieGrid title="💰 Top Grossing" movies={data.topGrossing.slice(0, 18)} />
    </div>
  );
}
