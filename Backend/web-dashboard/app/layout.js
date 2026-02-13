import "./globals.css";

export const metadata = {
  title: "Box Officer Dashboard",
  description: "Box office analytics and movie financial data — powered by the same Firebase source of truth as the iOS app.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className="min-h-screen">
        <nav className="sticky top-0 z-50 backdrop-blur-md bg-white/80 dark:bg-black/80 border-b border-gray-200 dark:border-gray-800">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between h-16 items-center">
              <div className="flex items-center gap-2">
                <span className="text-2xl">🎬</span>
                <h1 className="text-xl font-bold">Box Officer</h1>
              </div>
              <div className="flex gap-4 text-sm text-gray-500">
                <a href="/" className="hover:text-blue-500 transition">Dashboard</a>
                <a href="/trending" className="hover:text-blue-500 transition">Trending</a>
                <a href="/search" className="hover:text-blue-500 transition">Search</a>
              </div>
            </div>
          </div>
        </nav>
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {children}
        </main>
      </body>
    </html>
  );
}
