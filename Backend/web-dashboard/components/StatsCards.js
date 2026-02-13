"use client";

function StatCard({ title, value, icon, color }) {
  return (
    <div className="bg-white dark:bg-[#1c1c1e] rounded-xl p-5 shadow-sm">
      <div className="flex items-center gap-3 mb-2">
        <span className="text-2xl">{icon}</span>
        <span className="text-sm text-gray-500">{title}</span>
      </div>
      <p className={`text-2xl font-bold ${color || ""}`}>{value}</p>
    </div>
  );
}

export default function StatsCards({ movies }) {
  const totalMovies = movies.length;
  const avgRating =
    totalMovies > 0
      ? (movies.reduce((sum, m) => sum + (m.vote_average || 0), 0) / totalMovies).toFixed(1)
      : "N/A";
  const totalRevenue = movies.reduce((sum, m) => sum + (m.revenue || 0), 0);
  const formattedRevenue =
    totalRevenue > 1_000_000_000
      ? `$${(totalRevenue / 1_000_000_000).toFixed(1)}B`
      : totalRevenue > 1_000_000
      ? `$${(totalRevenue / 1_000_000).toFixed(0)}M`
      : totalRevenue > 0
      ? `$${totalRevenue.toLocaleString()}`
      : "N/A";

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      <StatCard title="Movies Tracked" value={totalMovies} icon="🎬" />
      <StatCard title="Avg Rating" value={`⭐ ${avgRating}`} icon="📊" />
      <StatCard
        title="Total Box Office"
        value={formattedRevenue}
        icon="💰"
        color="text-green-600 dark:text-green-400"
      />
      <StatCard title="Data Source" value="Firebase" icon="🔥" color="text-orange-500" />
    </div>
  );
}
