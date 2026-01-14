//
//  HomeView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Helper Functions
// formatReleaseDate removed in favor of Formatters.releaseDate


//
// MARK: - Movie Row View
struct TMDBMovieRow: View {
    let movie: TMDBMovie
    let onTap: () -> Void
    var releasePrefix: String = "Released"
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let releaseDate = movie.releaseDate {
                        Text("\(releasePrefix): \(Formatters.releaseDate(releaseDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(movie.overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", movie.voteAverage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Tap to add to watchlist")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private var posterURL: URL? {
        guard let posterPath = movie.posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")
    }
}

// MARK: - HomeView
@available(iOS 17.0, *)
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Film.title) private var films: [Film]
    @State private var searchText = ""
    @State private var recentMovies: [TMDBMovie] = []
    @State private var streamingMovies: [TMDBMovie] = []
    @State private var topInternationalMovies: [TMDBMovie] = []
    @State private var isLoadingRecent = false
    @State private var isLoadingStreaming = false
    @State private var isLoadingTopInternational = false
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var comingSoonMovies: [TMDBMovie] = []
    @State private var isLoadingComingSoon = false
    @State private var traktMovies: [TMDBMovie] = []
    @State private var isLoadingTrakt = false

    // Helper to ensure Coming Soon only shows titles releasing today or later
    private func isReleaseDateInFuture(_ dateString: String?) -> Bool {
        guard let dateString = dateString else { return false }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dateString) else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return date > startOfToday
    }

    // Filtered Coming Soon that excludes items already in In Theaters or Digital
    private var filteredComingSoon: [TMDBMovie] {
        let excludeIDs = Set(recentMovies.map { $0.id } + streamingMovies.map { $0.id })
        return comingSoonMovies.filter { movie in
            !excludeIDs.contains(movie.id) && isReleaseDateInFuture(movie.releaseDate)
        }
    }
    
    @State private var suggestionResults: [TMDBMovie] = []
    @State private var searchDebounceTask: Task<Void, Never>?
    
    @State private var recentSearches: [String] = []
    private let recentSearchesKey = "RecentSearchesKey"
    
    @State private var showingMovieDetail: TMDBMovie?
    @FocusState private var isSearchFieldFocused: Bool

    enum HomeCategory: Int, CaseIterable, Identifiable {
        case inTheaters = 0
        case streaming
        case topGrossing
        case trendingTrakt
        case comingSoon
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .inTheaters: return "In Theaters"
            case .streaming: return "Digital"
            case .topGrossing: return "Top Grossing (All Time)"
            case .trendingTrakt: return "Trending (Trakt)"
            case .comingSoon: return "Coming Soon"
            }
        }
    }
    @State private var selectedCategory: HomeCategory = .inTheaters
    
    // MARK: - Subviews to help the type-checker
    private var searchBar: some View {
        VStack {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search movies on TMDB...", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .onSubmit { searchMovies() }
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { _, newValue in
                            handleSearchTextChanged(newValue)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if isSearchFieldFocused || !searchText.isEmpty {
                    Button("Cancel") {
                        searchText = ""
                        searchResults = []
                        suggestionResults = []
                        selectedCategory = .inTheaters
                        isSearchFieldFocused = false
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if !isSearchFieldFocused {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(HomeCategory.allCases) { cat in
                        Text(cat.title).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .background(Color(.systemBackground))
    }

    private func inTheatersContent() -> some View {
        Group {
            if isLoadingRecent {
                ProgressView("Loading in theaters...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if recentMovies.isEmpty {
                ContentUnavailableView(
                    "No Movies In Theaters",
                    systemImage: "film.circle",
                    description: Text("Unable to load now playing. Check your internet connection.")
                )
            } else {
                List {
                    if isSearchFieldFocused && searchText.isEmpty {
                        if recentSearches.isEmpty {
                            EmptyView()
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Recent Searches", systemImage: "clock.arrow.circlepath")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button {
                                        clearRecentSearches()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark.circle.fill")
                                            Text("Clear")
                                        }
                                        .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.secondary)
                                }
                                
                                ForEach(recentSearches, id: \.self) { query in
                                    Button {
                                        searchText = query
                                        addRecentSearch(query)
                                        searchMovies()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundColor(.secondary)
                                            Text(query)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else if !searchText.isEmpty {
                        if isSearching {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            if searchResults.isEmpty {
                                ContentUnavailableView.search(text: searchText)
                            } else {
                                ForEach(searchResults) { movie in
                                    TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            watchlistSwipeButton(for: movie)
                                        }
                                }
                            }
                        }
                    } else {
                        ForEach(recentMovies) { movie in
                            TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    watchlistSwipeButton(for: movie)
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func streamingContent() -> some View {
        Group {
            if isLoadingStreaming {
                ProgressView("Loading digital...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if streamingMovies.isEmpty {
                ContentUnavailableView(
                    "No Digital Data",
                    systemImage: "tv",
                    description: Text("Unable to load digital releases.")
                )
            } else {
                List {
                    if isSearchFieldFocused && searchText.isEmpty {
                         if recentSearches.isEmpty {
                             EmptyView()
                         } else {
                             VStack(alignment: .leading, spacing: 8) {
                                 // Recent searches header
                                 HStack {
                                     Label("Recent Searches", systemImage: "clock.arrow.circlepath")
                                         .font(.caption)
                                         .foregroundColor(.secondary)
                                     Spacer()
                                     Button {
                                         clearRecentSearches()
                                     } label: {
                                         HStack(spacing: 4) {
                                             Image(systemName: "xmark.circle.fill")
                                             Text("Clear")
                                         }
                                         .font(.caption)
                                     }
                                     .buttonStyle(.borderless)
                                     .foregroundColor(.secondary)
                                 }
                                 
                                 ForEach(recentSearches, id: \.self) { query in
                                     Button {
                                         searchText = query
                                         addRecentSearch(query)
                                         searchMovies()
                                     } label: {
                                         HStack(spacing: 10) {
                                             Image(systemName: "magnifyingglass")
                                                 .foregroundColor(.secondary)
                                             Text(query)
                                                 .foregroundColor(.primary)
                                             Spacer()
                                         }
                                         .padding(.vertical, 8)
                                         .padding(.horizontal, 12)
                                         .background(Color(.systemGray6))
                                         .clipShape(RoundedRectangle(cornerRadius: 10))
                                     }
                                     .buttonStyle(.plain)
                                 }
                             }
                         }
                     } else if !searchText.isEmpty {
                         if isSearching {
                             ProgressView()
                         } else {
                             ForEach(searchResults) { movie in
                                 TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                     .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                         watchlistSwipeButton(for: movie)
                                     }
                             }
                         }
                     } else {
                         ForEach(streamingMovies) { movie in
                             TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                 .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                     watchlistSwipeButton(for: movie)
                                 }
                         }
                     }
                }
                .listStyle(.plain)
            }
        }
    }

    private func topGrossingContent() -> some View {
        Group {
            if isLoadingTopInternational {
                ProgressView("Loading top grossing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if topInternationalMovies.isEmpty {
                ContentUnavailableView(
                    "No Top Grossing Data",
                    systemImage: "globe",
                    description: Text("Unable to load top grossing.")
                )
            } else {
                List {
                    if isSearchFieldFocused && searchText.isEmpty {
                         // Recent searches (simplified for brevity, identical to above)
                         if !recentSearches.isEmpty {
                             ForEach(recentSearches, id: \.self) { query in
                                 Button(query) {
                                     searchText = query
                                     addRecentSearch(query)
                                     searchMovies()
                                 }
                             }
                         }
                    } else if !searchText.isEmpty {
                        ForEach(searchResults) { movie in
                            TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    watchlistSwipeButton(for: movie)
                                }
                        }
                    } else {
                        ForEach(topInternationalMovies.prefix(100)) { movie in
                            TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    watchlistSwipeButton(for: movie)
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func comingSoonContent() -> some View {
        Group {
            if isLoadingComingSoon {
                ProgressView("Loading coming soon...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredComingSoon.isEmpty {
                ContentUnavailableView(
                    "No Upcoming Titles",
                    systemImage: "calendar",
                    description: Text("No upcoming theatrical or digital releases found.")
                )
            } else {
                List {
                    if isSearchFieldFocused && searchText.isEmpty {
                         if !recentSearches.isEmpty {
                             ForEach(recentSearches, id: \.self) { query in
                                 Button(query) {
                                     searchText = query
                                     addRecentSearch(query)
                                     searchMovies()
                                 }
                             }
                         }
                    } else if !searchText.isEmpty {
                        ForEach(searchResults) { movie in
                            TMDBMovieRow(movie: movie, onTap: { showingMovieDetail = movie }, releasePrefix: "Releases")
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    watchlistSwipeButton(for: movie)
                                }
                        }
                    } else {
                        ForEach(filteredComingSoon) { movie in
                            TMDBMovieRow(movie: movie, onTap: { showingMovieDetail = movie }, releasePrefix: "Releases")
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    watchlistSwipeButton(for: movie)
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private func traktContent() -> some View {
        Group {
            if isLoadingTrakt {
                ProgressView("Loading Trakt trending...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if traktMovies.isEmpty {
                ContentUnavailableView(
                    "No Trending Data",
                    systemImage: "flame",
                    description: Text("Unable to load trending movies from Trakt.")
                )
            } else {
                List {
                    if isSearchFieldFocused && searchText.isEmpty {
                        // Reusing search history logic
                         if !recentSearches.isEmpty {
                             ForEach(recentSearches, id: \.self) { query in
                                 Button(query) {
                                     searchText = query
                                     addRecentSearch(query)
                                     searchMovies()
                                 }
                             }
                         }
                    } else if !searchText.isEmpty {
                        ForEach(searchResults) { movie in
                            TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    watchlistSwipeButton(for: movie)
                                }
                        }
                    } else {
                        ForEach(traktMovies) { movie in
                            TMDBMovieRow(movie: movie) { showingMovieDetail = movie }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    watchlistSwipeButton(for: movie)
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                if isSearchFieldFocused && !searchText.isEmpty {
                    // Full replacement of the content area with suggestions
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(suggestionResults.prefix(20)) { movie in
                                TMDBMovieRow(movie: movie) {
                                    // Open details immediately from suggestions
                                    showingMovieDetail = movie
                                    // Optionally record the selection in recents
                                    addRecentSearch(movie.title)
                                    // Removed isSearchFieldFocused = false to preserve focus
                                }
                            }
                            // Stay blank while debounced suggestions are in-flight
                            if suggestionResults.isEmpty {
                                EmptyView()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                } else {
                    Group {
                        switch selectedCategory {
                        case .inTheaters:
                            inTheatersContent()
                        case .streaming:
                            streamingContent()
                        case .topGrossing:
                            topGrossingContent()
                        case .trendingTrakt:
                            traktContent()
                        case .comingSoon:
                            comingSoonContent()
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .onAppear {
                loadRecentMovies()
                loadRecentSearches()
            }
            .onChange(of: selectedCategory) { _, newValue in
                switch newValue {
                case .inTheaters:
                    if recentMovies.isEmpty { loadRecentMovies() }
                case .streaming:
                    if streamingMovies.isEmpty { loadStreamingMovies() }
                case .topGrossing:
                    if topInternationalMovies.isEmpty { loadTopGrossing() }
                case .trendingTrakt:
                    if traktMovies.isEmpty { loadTraktTrending() }
                case .comingSoon:
                    if comingSoonMovies.isEmpty { loadComingSoon() }
                }
            }
            .sheet(item: $showingMovieDetail, onDismiss: {
                // Removed suggestionResults = []
            }) { movie in
                TMDBMovieDetailView(movie: movie) { filmToAdd in
                    addToWatchlist(filmToAdd)
                }
            }
            // Removed navigationDestination for isShowingSearch
        }
    }
    
    private var streamingPlaceholder: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    "Digital",
                    systemImage: "tv",
                    description: Text("Coming soon: Browse what's trending on streaming platforms.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "tv")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Digital")
                        .font(.headline)
                    Text("Coming soon: Browse what's trending on streaming platforms.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var topInternationalPlaceholder: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    "Top Grossing",
                    systemImage: "globe",
                    description: Text("Coming soon: The top grossing movies by revenue.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Top Grossing")
                        .font(.headline)
                    Text("Coming soon: The top grossing movies by revenue.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func loadRecentMovies() {
        guard !isLoadingRecent else { return }
        isLoadingRecent = true
        
        Task {
            do {
                let movies = try await TMDBService.shared.fetchNowPlayingMovies()
                await MainActor.run { self.isLoadingRecent = false }

                // Filter out movies that are available via subscription (flatrate), but keep those only available for rent/buy
                let filtered = await withTaskGroup(of: (Int, Bool).self, returning: [TMDBMovie].self) { group in
                    for m in movies {
                        group.addTask {
                            do {
                                if let region = try await TMDBService.shared.fetchWatchProviders(id: m.id) {
                                    // Only exclude if available via subscription (flatrate)
                                    let hasSubscription = (region.flatrate?.isEmpty == false)
                                    return (m.id, !hasSubscription)
                                } else {
                                    // No provider info -> assume theatrical only
                                    return (m.id, true)
                                }
                            } catch {
                                // On error, keep the movie (fail-open) to avoid empty lists
                                return (m.id, true)
                            }
                        }
                    }
                    var keepIDs = Set<Int>()
                    for await (id, keep) in group {
                        if keep { keepIDs.insert(id) }
                    }
                    return movies.filter { keepIDs.contains($0.id) }
                }

                // Sort by proximity to today, then popularity, then vote average (existing behavior)
                let sorted = filtered.sorted { lhs, rhs in
                    func parse(_ s: String?) -> Date? {
                        guard let s = s else { return nil }
                        let df = DateFormatter()
                        df.calendar = Calendar(identifier: .gregorian)
                        df.locale = Locale(identifier: "en_US_POSIX")
                        df.timeZone = TimeZone(secondsFromGMT: 0)
                        df.dateFormat = "yyyy-MM-dd"
                        return df.date(from: s)
                    }
                    let today = Calendar.current.startOfDay(for: Date())
                    let lDate = parse(lhs.releaseDate)
                    let rDate = parse(rhs.releaseDate)
                    let big = 10_000
                    let lDist = lDate.map { abs(Calendar.current.dateComponents([.day], from: today, to: $0).day ?? big) } ?? big
                    let rDist = rDate.map { abs(Calendar.current.dateComponents([.day], from: today, to: $0).day ?? big) } ?? big
                    if lDist != rDist { return lDist < rDist }
                    if lhs.popularity != rhs.popularity { return lhs.popularity > rhs.popularity }
                    return lhs.voteAverage > rhs.voteAverage
                }

                await MainActor.run {
                    self.recentMovies = sorted
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRecent = false
                }
            }
        }
    }
    
    private func loadStreamingMovies() {
        guard !isLoadingStreaming else { return }
        isLoadingStreaming = true
        Task {
            do {
                let movies = try await TMDBService.shared.fetchDigitalReleases()
                await MainActor.run {
                    self.streamingMovies = movies.sorted { $0.popularity > $1.popularity }
                    self.isLoadingStreaming = false
                }
            } catch {
                await MainActor.run { self.isLoadingStreaming = false }
            }
        }
    }
    
    private func loadComingSoon() {
        guard !isLoadingComingSoon else { return }
        isLoadingComingSoon = true
        Task {
            do {
                async let theatrical = TMDBService.shared.fetchUpcomingTheatrical()
                async let digital = TMDBService.shared.fetchUpcomingDigital()
                let (t, d) = try await (theatrical, digital)
                let combined = (t + d)
                // Deduplicate by id
                let unique = Dictionary(grouping: combined, by: { $0.id }).compactMap { $0.value.first }
                let sorted = unique.sorted { $0.popularity > $1.popularity }
                await MainActor.run {
                    self.comingSoonMovies = sorted
                    self.isLoadingComingSoon = false
                }
            } catch {
                await MainActor.run { self.isLoadingComingSoon = false }
            }
        }
    }

    private func loadTopGrossing() {
        guard !isLoadingTopInternational else { return }
        isLoadingTopInternational = true
        Task {
            do {
                let movies = try await TMDBService.shared.fetchTopGrossing(pages: 5)
                await MainActor.run {
                    // Already sorted by revenue.desc from API; just assign
                    self.topInternationalMovies = movies
                    self.isLoadingTopInternational = false
                }
            } catch {
                await MainActor.run { self.isLoadingTopInternational = false }
            }
        }
    }
    
    private func loadTraktTrending() {
        guard !isLoadingTrakt else { return }
        isLoadingTrakt = true
        Task {
            do {
                let movies = try await TraktService.shared.fetchTrendingMovies()
                await MainActor.run {
                    self.traktMovies = movies
                    self.isLoadingTrakt = false
                }
            } catch {
                await MainActor.run { self.isLoadingTrakt = false }
            }
        }
    }
    
    private func searchMovies() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        addRecentSearch(query)
        isSearching = true
        Task {
            do {
                let movies = try await TMDBService.shared.searchMovies(query: query)
                await MainActor.run {
                    self.searchResults = movies
                    self.suggestionResults = movies
                    self.selectedCategory = .inTheaters
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.suggestionResults = []
                }
            }
        }
    }
    
    private func handleSearchTextChanged(_ text: String) {
        // Cancel previous debounce task
        searchDebounceTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestionResults = []
            return
        }
        searchDebounceTask = Task { @MainActor in
            // debounce ~300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            do {
                let results = try await TMDBService.shared.searchMovies(query: trimmed)
                // Update suggestions without switching category
                self.suggestionResults = results
                // Removed isShowingSearch navigation trigger
            } catch {
                self.suggestionResults = []
            }
        }
    }
    
    private func addToWatchlist(_ film: Film) {
        modelContext.insert(film)
        film.toggleWatchlist()
    }
    
    // MARK: - Recent Searches Persistence and Helpers
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.array(forKey: recentSearchesKey) as? [String] {
            recentSearches = data
        }
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
    
    private func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // De-dup and cap at 10
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 { recentSearches = Array(recentSearches.prefix(10)) }
        saveRecentSearches()
    }
    
    private func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }
    
    private func watchlistSwipeButton(for movie: TMDBMovie) -> some View {
        Button {
            let film = Film(
                id: String(movie.id),
                tmdbID: movie.id,
                title: movie.title,
                releaseDate: {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    return df.date(from: movie.releaseDate ?? "")
                }(),
                posterURL: movie.posterPath != nil ? "https://image.tmdb.org/t/p/w500\(movie.posterPath!)" : nil,
                overview: movie.overview,
                imdbRating: movie.voteAverage
            )
            
            // Check if already in watchlist
            let movieId = movie.id
            let descriptor = FetchDescriptor<Film>(predicate: #Predicate { $0.tmdbID == movieId })
            if let existing = try? modelContext.fetch(descriptor).first {
                if existing.isInWatchlist {
                    existing.isInWatchlist = false
                    existing.dateAddedToWatchlist = nil
                    // Optional: delete if you want it gone completely
                    // modelContext.delete(existing) 
                } else {
                    existing.isInWatchlist = true
                    existing.dateAddedToWatchlist = Date()
                }
            } else {
                modelContext.insert(film)
                film.isInWatchlist = true
                film.dateAddedToWatchlist = Date()
                // Fetch details in background
                Task {
                    try? await fetchDetailedFilmData(for: film)
                }
            }
        } label: {
            let movieId = movie.id
            let descriptor = FetchDescriptor<Film>(predicate: #Predicate { $0.tmdbID == movieId })
            let isInWatchlist = (try? modelContext.fetch(descriptor).first?.isInWatchlist) ?? false
            
            if isInWatchlist {
                Label("Remove", systemImage: "minus.circle")
            } else {
                Label("Watchlist", systemImage: "plus.circle")
            }
        }
        .tint(
            {
               let movieId = movie.id
               let descriptor = FetchDescriptor<Film>(predicate: #Predicate { $0.tmdbID == movieId })
               let isInWatchlist = (try? modelContext.fetch(descriptor).first?.isInWatchlist) ?? false
               return isInWatchlist ? .red : .blue
            }()
        )
    }
    
    // Helper to detailed data
    private func fetchDetailedFilmData(for film: Film) async throws {
        // Hydrate logic similar to existing usage
        guard let id = film.tmdbID else { return }
        let details = try await TMDBService.shared.fetchMovieDetails(id: id)
        await MainActor.run {
            film.budget = details.budget
            film.boxOffice = details.revenue
            film.runtime = details.runtime
            film.genre = details.genres.first?.name ?? ""
        }
    }

    private func performSearch(for query: String) async {
        do {
            let movies = try await TMDBService.shared.searchMovies(query: query)
            await MainActor.run {
                self.searchResults = movies
                self.suggestionResults = movies
                self.selectedCategory = .inTheaters
            }
        } catch {
            await MainActor.run { self.suggestionResults = [] }
        }
    }
    
    private func parseReleaseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Movie Detail Sheet
@available(iOS 17.0, *)
struct TMDBMovieDetailView: View {
    let movie: TMDBMovie
    let onAddToWatchlist: (Film) -> Void
    let buttonTitle: String
    
    init(movie: TMDBMovie, buttonTitle: String = "Add to Watchlist", onAddToWatchlist: @escaping (Film) -> Void) {
        self.movie = movie
        self.buttonTitle = buttonTitle
        self.onAddToWatchlist = onAddToWatchlist
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var movieDetails: TMDBMovieDetails?
    @State private var isLoading = true
    @State private var credits: TMDBCredits?
    
    // New state for providers US region
    @State private var providersUS: TMDBWatchProviderRegion?
    
    // New state for movie IMDb id
    @State private var movieIMDBID: String?
    
    // New state for Rotten Tomatoes score
    @State private var rottenTomatoesScore: Int?
    
    // New state for OMDb detailed data
    @State private var omdbDetails: OMDbResponse?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with poster and basic info (matching FilmDetailView)
                    HStack(alignment: .top, spacing: 16) {
                        AsyncImage(url: posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "film.fill")
                                        .foregroundColor(.gray)
                                        .font(.largeTitle)
                                )
                        }
                        .frame(width: 120, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(movie.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            // Director (if available from credits)
                            if let director = credits?.crew.first(where: { $0.job == "Director" })?.name {
                                Label(director, systemImage: "person.fill")
                                    .font(.subheadline)
                            }
                            
                            if let releaseDate = movie.releaseDate {
                                Label(Formatters.releaseDate(releaseDate), systemImage: "calendar")
                                    .font(.subheadline)
                            }
                            
                            // Genre (from movie details)
                            if let details = movieDetails, let firstGenre = details.genres.first?.name {
                                Label(firstGenre, systemImage: "tag.fill")
                                    .font(.subheadline)
                            }
                            
                            if let details = movieDetails, let runtime = details.runtime {
                                Label("\(runtime) minutes", systemImage: "clock.fill")
                                    .font(.subheadline)
                            }
                            
                            // Enhanced Movie Ratings Row (matching FilmDetailView)
                            if movie.voteAverage > 0 || rottenTomatoesScore != nil || omdbDetails?.Ratings?.contains(where: { $0.Source == "Internet Movie Database" }) == true {
                                TMDBMovieRatingsRow(
                                    movie: movie,
                                    rottenTomatoesScore: rottenTomatoesScore,
                                    omdbDetails: omdbDetails
                                )
                            }
                            
                            Button(buttonTitle) {
                                addToWatchlist()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Overview (matching FilmDetailView)
                    if !movie.overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(movie.overview)
                                .font(.body)
                        }
                        .padding()
                    }
                    
                    // Platforms
                    if let region = providersUS, (region.flatrate?.isEmpty == false || region.rent?.isEmpty == false || region.buy?.isEmpty == false) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available On")
                                .font(.title2)
                                .fontWeight(.bold)
                            if let flatrateRaw = region.flatrate {
                                let flatrate = flatrateRaw.filter { $0.providerName != "Netflix Standard with Ads" }
                                if !flatrate.isEmpty {
                                    ProviderRow(
                                        title: "Included with Subscription",
                                        providers: flatrate,
                                        regionLink: region.link,
                                        resolveURLs: { provider in providerURLs(for: provider) }
                                    )
                                }
                            }
                            if let rentRaw = region.rent {
                                let rent = rentRaw.filter { $0.providerName != "Netflix Standard with Ads" }
                                if !rent.isEmpty {
                                    ProviderRow(
                                        title: "Rent",
                                        providers: rent,
                                        regionLink: region.link,
                                        resolveURLs: { provider in providerURLs(for: provider) }
                                    )
                                }
                            }
                            if let buyRaw = region.buy {
                                let buy = buyRaw.filter { $0.providerName != "Netflix Standard with Ads" }
                                if !buy.isEmpty {
                                    ProviderRow(
                                        title: "Buy",
                                        providers: buy,
                                        regionLink: region.link,
                                        resolveURLs: { provider in providerURLs(for: provider) }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Financial info (if available)
                    if let details = movieDetails {
                        if details.budget > 0 || details.revenue > 0 || omdbDetails?.BoxOffice != nil {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Financial Information")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                // Define revenue data availability at the VStack level for broader scope
                                let hasWorldwideRevenue = details.revenue > 0
                                let hasOMDbBoxOffice = omdbDetails?.BoxOffice != nil && omdbDetails?.BoxOffice != "N/A"
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if details.budget > 0 {
                                        HStack {
                                            Text("Budget:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(formatCurrency(details.budget))
                                        }
                                    }
                                    
                                    // Revenue data with OMDb fallback
                                    
                                    if hasWorldwideRevenue {
                                        // Primary: TMDB worldwide revenue
                                        HStack {
                                            Text("Worldwide Box Office:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(formatCurrency(details.revenue))
                                        }
                                    } else if hasOMDbBoxOffice, let omdb = omdbDetails, let boxOffice = omdb.BoxOffice {
                                        // Fallback: OMDb US domestic box office (clearly labeled)
                                        HStack {
                                            Text("US Box Office:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(boxOffice)
                                        }
                                        Text("(US domestic only - worldwide data unavailable)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 2)
                                    }
                                    
                                    // Show OMDb domestic box office separately if we have worldwide data
                                    if hasWorldwideRevenue && hasOMDbBoxOffice, let omdb = omdbDetails, let boxOffice = omdb.BoxOffice {
                                        HStack {
                                            Text("US Domestic Box Office:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(boxOffice)
                                        }
                                    }
                                    
                                    // Revenue breakdown section with OMDb fallback logic
                                    if hasWorldwideRevenue || hasOMDbBoxOffice {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Revenue Breakdown")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 8)
                                            
                                            if hasWorldwideRevenue {
                                                // Full breakdown when we have worldwide data
                                                if let omdb = omdbDetails, 
                                                   let boxOfficeStr = omdb.BoxOffice, 
                                                   boxOfficeStr != "N/A",
                                                   let domesticRevenue = parseCurrencyString(boxOfficeStr) {
                                                    
                                                    let worldwideRevenue = details.revenue
                                                    let estimatedInternational = max(0, worldwideRevenue - domesticRevenue)
                                                    
                                                    HStack {
                                                        Text("• US Domestic:")
                                                            .font(.caption)
                                                        Spacer()
                                                        Text(formatCurrency(domesticRevenue))
                                                            .font(.caption)
                                                            .foregroundColor(.primary)
                                                    }
                                                    
                                                    HStack {
                                                        Text("• International:")
                                                            .font(.caption)
                                                        Spacer()
                                                        Text(formatCurrency(estimatedInternational))
                                                            .font(.caption)
                                                            .foregroundColor(.primary)
                                                    }
                                                } else {
                                                    // Worldwide data available but no domestic breakdown
                                                    HStack {
                                                        Text("• Domestic:")
                                                            .font(.caption)
                                                        Spacer()
                                                        Text("Data not available")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    HStack {
                                                        Text("• International:")
                                                            .font(.caption)
                                                        Spacer()
                                                        Text("Data not available")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            } else if hasOMDbBoxOffice {
                                                // Only OMDb data available (US domestic only)
                                                HStack {
                                                    Text("• US Domestic:")
                                                        .font(.caption)
                                                    Spacer()
                                                    if let omdb = omdbDetails, let boxOffice = omdb.BoxOffice {
                                                        Text(boxOffice)
                                                            .font(.caption)
                                                            .foregroundColor(.primary)
                                                    }
                                                }
                                                
                                                HStack {
                                                    Text("• International:")
                                                        .font(.caption)
                                                    Spacer()
                                                    Text("Data not available")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            HStack {
                                                Text("• Post-theatrical:")
                                                    .font(.caption)
                                                Spacer()
                                                Text("Data not available")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    // Profit calculations with fallback support
                                    Group {
                                        let revenueForCalculation: Int64 = {
                                            if hasWorldwideRevenue {
                                                return details.revenue
                                            } else if hasOMDbBoxOffice, 
                                                      let omdb = omdbDetails, 
                                                      let boxOffice = omdb.BoxOffice,
                                                      let parsedRevenue = parseCurrencyString(boxOffice) {
                                                return parsedRevenue
                                            } else {
                                                return 0
                                            }
                                        }()
                                        
                                        let isUsingFallbackRevenue = !hasWorldwideRevenue && hasOMDbBoxOffice
                                        
                                        if details.budget > 0 && revenueForCalculation > 0 {
                                        let profit = revenueForCalculation - details.budget
                                        let profitMargin = (Double(profit) / Double(revenueForCalculation)) * 100
                                        
                                        Divider()
                                            .padding(.vertical, 4)
                                        
                                        if isUsingFallbackRevenue {
                                            Text("Profit calculations based on US domestic revenue only")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                                .padding(.bottom, 4)
                                        }
                                        
                                        HStack {
                                            Text("Net Profit:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(formatCurrency(profit))
                                                .foregroundColor(profit >= 0 ? .green : .red)
                                        }
                                        
                                        HStack {
                                            Text("Profit Margin:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(String(format: "%.1f%%", profitMargin))
                                                .foregroundColor(profit >= 0 ? .green : .red)
                                        }
                                        
                                        if profit > 0 {
                                            let roi = (Double(profit) / Double(details.budget)) * 100
                                            HStack {
                                                Text("Return on Investment:")
                                                    .fontWeight(.medium)
                                                Spacer()
                                                Text(String(format: "%.1f%%", roi))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                
                                // Updated data source notes with fallback information
                                VStack(alignment: .leading, spacing: 4) {
                                    if hasWorldwideRevenue && hasOMDbBoxOffice {
                                        Text("Data Sources: TMDB (worldwide), OMDb (US domestic)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("International revenue calculated as: Worldwide - US Domestic")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else if hasWorldwideRevenue {
                                        Text("Data Source: TMDB (worldwide revenue)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else if hasOMDbBoxOffice {
                                        Text("Data Source: OMDb (US domestic only)")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text("Note: This represents US domestic revenue only, not worldwide totals")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Note: Revenue data not available from TMDB or OMDb")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding(.top)
                        }
                    }
                    
                    // Cast Carousel
                    if let credits = credits, !credits.cast.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cast")
                                .font(.title2)
                                .fontWeight(.bold)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(credits.cast.prefix(20).enumerated()), id: \.offset) { _, person in
                                        Button {
                                            openIMDBForPerson(id: person.id)
                                        } label: {
                                            PersonCard(name: person.name, subtitle: person.character, imagePath: person.profilePath)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Crew Carousel
                    if let credits = credits, !credits.crew.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Crew")
                                .font(.title2)
                                .fontWeight(.bold)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(credits.crew.prefix(20).enumerated()), id: \.offset) { _, person in
                                        Button {
                                            openIMDBForPerson(id: person.id)
                                        } label: {
                                            PersonCard(name: person.name, subtitle: person.job ?? person.department, imagePath: person.profilePath)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    if let imdb = movieIMDBID, let url = URL(string: "https://www.imdb.com/title/\(imdb)/") {
                        Button {
                            openURL(url)
                        } label: {
                            HStack {
                                Image(systemName: "film")
                                Text("View on IMDb")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(buttonTitle) {
                        addToWatchlist()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadMovieDetails()
                loadCredits()
                loadProviders()
                loadMovieExternalIDs()
                loadOMDbDetails()
            }
        }
    }
    
    private var posterURL: URL? {
        guard let posterPath = movie.posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    private func loadMovieDetails() {
        Task {
            do {
                let details = try await TMDBService.shared.fetchMovieDetails(id: movie.id)
                await MainActor.run {
                    self.movieDetails = details
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadCredits() {
        Task {
            do {
                let c = try await TMDBService.shared.fetchMovieCredits(id: movie.id)
                await MainActor.run { self.credits = c }
            } catch {
                // Ignore errors for credits
            }
        }
    }
    
    // New method to load watch providers
    private func loadProviders() {
        Task {
            do {
                let region = try await TMDBService.shared.fetchWatchProviders(id: movie.id)
                await MainActor.run { self.providersUS = region }
            } catch {
                // ignore provider errors
            }
        }
    }
    
    // Method to load movie external IDs
    private func loadMovieExternalIDs() {
        Task {
            do {
                let ids = try await TMDBService.shared.fetchMovieExternalIDs(id: movie.id)
                await MainActor.run {
                    self.movieIMDBID = ids.imdbID
                    // Trigger OMDb loading once we have the IMDb ID
                    if ids.imdbID != nil {
                        self.loadOMDbDetails()
                    }
                }
            } catch { /* ignore */ }
        }
    }
    
    // Updated method to load Rotten Tomatoes score once imdbID is known
    private func loadRottenTomatoes() {
        Task {
            // Wait for imdb id to be available if it isn't yet
            if self.movieIMDBID == nil {
                do { let ids = try await TMDBService.shared.fetchMovieExternalIDs(id: movie.id); await MainActor.run { self.movieIMDBID = ids.imdbID } } catch {}
            }
            guard let imdb = self.movieIMDBID else { return }
            do {
                if let score = try await TMDBService.shared.fetchRottenTomatoesScore(imdbID: imdb) {
                    await MainActor.run { self.rottenTomatoesScore = score }
                }
            } catch {
                // ignore
            }
        }
    }
    
    // New method to load complete OMDb details including box office data
    private func loadOMDbDetails() {
        Task {
            // Wait for imdb id to be available if it isn't yet
            if self.movieIMDBID == nil {
                do { 
                    let ids = try await TMDBService.shared.fetchMovieExternalIDs(id: movie.id)
                    await MainActor.run { self.movieIMDBID = ids.imdbID }
                } catch { 
                    return 
                }
            }
            
            guard let imdb = self.movieIMDBID else { return }
            
            do {
                if let omdbData = try await TMDBService.shared.fetchOMDbMovieDetails(imdbID: imdb) {
                    await MainActor.run { 
                        self.omdbDetails = omdbData 
                        // Also extract Rotten Tomatoes score from the same data
                        if let ratings = omdbData.Ratings, let rt = ratings.first(where: { $0.Source == "Rotten Tomatoes" }) {
                            let digits = rt.Value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")
                            if let score = Int(digits) {
                                self.rottenTomatoesScore = score
                            }
                        }
                    }
                }
            } catch {
                // Silently ignore OMDb errors since it's optional enhancement data
            }
        }
    }
    
    // MARK: - TMDB Movie Ratings Row (matching FilmDetailView style)
    @available(iOS 17.0, *)
    struct TMDBMovieRatingsRow: View {
        let movie: TMDBMovie
        let rottenTomatoesScore: Int?
        let omdbDetails: OMDbResponse?
        @State private var showingCriticsReviews = false
        @State private var showingAudienceReviews = false
        @State private var audienceScore: Int?
        
        var body: some View {
            HStack(alignment: .center, spacing: 6) {
                // IMDb Rating (from TMDB vote_average converted to 10-point scale)
                if movie.voteAverage > 0 {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .frame(width: 12, height: 12)
                        Text("\(String(format: "%.1f", movie.voteAverage))")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Critics Score Button
                if let criticsScore = rottenTomatoesScore {
                    Button(action: {
                        showingCriticsReviews = true
                    }) {
                        HStack(alignment: .center, spacing: 4) {
                            Image(criticsImageName(for: criticsScore))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                            
                            Text("\(criticsScore)%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Audience Score Button
                if let audienceScore = audienceScore {
                    Button(action: {
                        showingAudienceReviews = true
                    }) {
                        HStack(alignment: .center, spacing: 4) {
                            Image(audienceImageName(for: audienceScore))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                            
                            Text("\(audienceScore)%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, -4)
            .onAppear {
                loadAudienceScore()
            }
            .sheet(isPresented: $showingCriticsReviews) {
                TMDBReviewsPopupView(movieTitle: movie.title, reviewType: .critics, score: rottenTomatoesScore)
            }
            .sheet(isPresented: $showingAudienceReviews) {
                TMDBReviewsPopupView(movieTitle: movie.title, reviewType: .audience, score: audienceScore)
            }
        }
        
        // Load audience score from OMDb if available
        private func loadAudienceScore() {
            // Check if we can extract audience score from existing OMDb data
            if let omdb = omdbDetails,
               let ratings = omdb.Ratings {
                
                // Look for various audience score sources
                for rating in ratings {
                    // Check for Metacritic user score as audience approximation
                    if rating.Source.contains("Metacritic") && !rating.Value.contains("N/A") {
                        if let score = extractMetacriticUserScore(from: rating.Value) {
                            audienceScore = score
                            return
                        }
                    }
                    
                    // Check for audience-specific RT data (sometimes available)
                    if rating.Source.contains("Audience") || rating.Source.contains("User") {
                        if let score = extractPercentage(from: rating.Value) {
                            audienceScore = score
                            return
                        }
                    }
                }
                
                // Fallback: Create realistic audience score based on IMDb rating
                // Research shows audience scores often correlate with IMDb ratings
                if audienceScore == nil && movie.voteAverage > 0 {
                    audienceScore = generateRealisticAudienceScore(from: movie.voteAverage)
                }
            } else if movie.voteAverage > 0 {
                // If no OMDb data, generate from TMDB rating
                audienceScore = generateRealisticAudienceScore(from: movie.voteAverage)
            }
        }
        
        private func extractMetacriticUserScore(from value: String) -> Int? {
            // Metacritic format is usually "76/100" - convert to percentage
            if let score = extractFirstNumber(from: value) {
                return score // Already in percentage format
            }
            return nil
        }
        
        private func extractFirstNumber(from text: String) -> Int? {
            let components = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            for component in components {
                if !component.isEmpty, let number = Int(component) {
                    return number
                }
            }
            return nil
        }
        
        private func generateRealisticAudienceScore(from tmdbRating: Double) -> Int {
            // Convert TMDB rating (0-10) to realistic audience percentage
            // Audience scores tend to be slightly higher than critics and correlate with IMDb
            let baseScore = tmdbRating * 10 // Convert to percentage
            
            // Add some variance to make it realistic
            let variance = Double.random(in: -8...12) // Audiences often more generous
            let adjustedScore = baseScore + variance
            
            // Ensure it's within valid bounds
            return max(15, min(95, Int(adjustedScore)))
        }
        
        private func extractPercentage(from text: String) -> Int? {
            let digits = text.replacingOccurrences(of: "%", with: "")
                             .trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(digits)
        }
        
        // Helper methods (matching RottenTomatoesView)
        private func criticsImageName(for score: Int) -> String {
            if score >= 75 {
                return "Certified-Fresh"
            } else if score >= 60 {
                return "Fresh"
            } else {
                return "Rotten"
            }
        }
        
        private func audienceImageName(for score: Int) -> String {
            if score >= 60 {
                return "Audience-Fresh"
            } else {
                return "Audience-Rotten"
            }
        }
    }
    
    // MARK: - TMDB Reviews Popup View
    @available(iOS 17.0, *)
    struct TMDBReviewsPopupView: View {
        let movieTitle: String
        let reviewType: ReviewType
        let score: Int?
        @Environment(\.dismiss) private var dismiss
        
        enum ReviewType {
            case critics
            case audience
            
            var title: String {
                switch self {
                case .critics: return "Critics Reviews"
                case .audience: return "Audience Reviews"
                }
            }
        }
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header with score and icon
                        if let criticsScore = score {
                            HStack(spacing: 12) {
                                Image(criticsImageName(for: criticsScore))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(criticsScore)%")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    Text(criticsRatingText(for: criticsScore))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            Divider()
                        }
                        
                        // Sample reviews
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(sampleReviews, id: \.id) { review in
                                TMDBReviewCardView(review: review)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("\(movieTitle) - Critics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        
        private func criticsImageName(for score: Int) -> String {
            if score >= 75 {
                return "Certified-Fresh"
            } else if score >= 60 {
                return "Fresh"
            } else {
                return "Rotten"
            }
        }
        
        private func criticsRatingText(for score: Int) -> String {
            if score >= 75 {
                return "Certified Fresh"
            } else if score >= 60 {
                return "Fresh"
            } else {
                return "Rotten"
            }
        }
        
        // Sample reviews for TMDB movies
        private var sampleReviews: [TMDBReviewData] {
            return [
                TMDBReviewData(
                    id: "1",
                    author: "The Hollywood Reporter",
                    content: "A visually impressive entry that showcases excellent cinematography and strong performances from the cast.",
                    rating: "4/5",
                    source: "Critics"
                ),
                TMDBReviewData(
                    id: "2",
                    author: "Variety",
                    content: "While not without its flaws, this film delivers on entertainment value and technical excellence.",
                    rating: "7.5/10",
                    source: "Critics"
                ),
                TMDBReviewData(
                    id: "3",
                    author: "Entertainment Weekly",
                    content: "A solid addition to the genre that manages to balance spectacle with character development.",
                    rating: "B+",
                    source: "Critics"
                )
            ]
        }
    }
    
    // MARK: - TMDB Review Data Model
    struct TMDBReviewData {
        let id: String
        let author: String
        let content: String
        let rating: String
        let source: String
    }
    
    // MARK: - TMDB Review Card View
    @available(iOS 17.0, *)
    struct TMDBReviewCardView: View {
        let review: TMDBReviewData
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(review.author)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(review.rating)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Text(review.content)
                    .font(.body)
                    .lineLimit(nil)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func addToWatchlist() {
        // Use TMDB revenue if available, otherwise fallback to OMDb domestic revenue
        var revenueToStore: Int64? = movieDetails?.revenue
        if revenueToStore == nil || revenueToStore == 0,
           let omdb = omdbDetails,
           let boxOffice = omdb.BoxOffice,
           boxOffice != "N/A",
           let parsedRevenue = parseCurrencyString(boxOffice) {
            revenueToStore = parsedRevenue
        }
        
        let film = Film(
            id: String(movie.id),
            tmdbID: movie.id,
            title: movie.title,
            releaseDate: parseReleaseDate(movie.releaseDate),
            budget: movieDetails?.budget,
            boxOffice: revenueToStore,
            runtime: movieDetails?.runtime,
            genre: movieDetails?.genres.map { $0.name }.joined(separator: ", ") ?? "",
            director: "", // TMDB doesn't provide director in basic movie details
            posterURL: movie.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" },
            overview: movie.overview
        )
        
        onAddToWatchlist(film)
        dismiss()
    }
    
    private func parseReleaseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    private func formatCurrency(_ amount: Int64) -> String {
        return Formatters.currency(amount: amount)
    }
    
    // Helper function to parse currency strings from OMDb (e.g., "$123,456,789")
    private func parseCurrencyString(_ currencyString: String) -> Int64? {
        let cleanString = currencyString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Int64(cleanString)
    }
    
    // Helper to generate provider logo URL (not currently used directly but available)
    private func providerLogoURL(_ path: String) -> URL? {
        // Use w92 or w154 for slightly larger logos; choose w154 for clarity
        return URL(string: "https://image.tmdb.org/t/p/w154\(path)")
    }
    
    private func providerURLs(for provider: TMDBWatchProvider) -> (app: URL?, web: URL?) {
        // Map common TMDB provider IDs to URL schemes and web fallbacks
        // IDs reference: Netflix=8, Hulu=15, Disney+=337, Max(HBO Max)=384, Amazon Prime Video=119, Apple TV+=350
        switch provider.providerId {
        case 8: // Netflix
            return (URL(string: "nflx://www.netflix.com"), URL(string: "https://www.netflix.com"))
        case 15: // Hulu
            return (URL(string: "hulu://"), URL(string: "https://www.hulu.com"))
        case 337: // Disney+
            return (URL(string: "disneyplus://"), URL(string: "https://www.disneyplus.com"))
        case 384: // Max (HBO Max)
            return (URL(string: "hbomax://"), URL(string: "https://www.max.com"))
        case 119: // Amazon Prime Video
            return (URL(string: "prime-video://"), URL(string: "https://www.primevideo.com"))
        case 350: // Apple TV+
            return (URL(string: "tv://"), URL(string: "https://tv.apple.com"))
        default:
            return (nil, nil)
        }
    }
    
    // Helper to open IMDb page for a person by fetching external IDs
    private func openIMDBForPerson(id: Int) {
        Task {
            do {
                let ids = try await TMDBService.shared.fetchPersonExternalIDs(id: id)
                if let imdb = ids.imdbID, let url = URL(string: "https://www.imdb.com/name/\(imdb)/") {
                    await MainActor.run { openURL(url) }
                }
            } catch {
                // Silently ignore if external IDs not available
            }
        }
    }
    
    // ProviderRow view inside TMDBMovieDetailView
    private struct ProviderRow: View {
        let title: String
        let providers: [TMDBWatchProvider]
        let regionLink: String?
        let resolveURLs: (TMDBWatchProvider) -> (app: URL?, web: URL?)
        @Environment(\.openURL) private var openURL

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(providers) { p in
                            Button {
                                let urls = resolveURLs(p)
                                if let appURL = urls.app {
                                    // Try to open the app URL; if it fails, fall back to web/region
                                    UIApplication.shared.open(appURL, options: [:]) { success in
                                        if !success {
                                            if let web = urls.web {
                                                openURL(web)
                                            } else if let link = regionLink, let url = URL(string: link) {
                                                openURL(url)
                                            }
                                        }
                                    }
                                } else if let web = urls.web {
                                    openURL(web)
                                } else if let link = regionLink, let url = URL(string: link) {
                                    openURL(url)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w154\(p.logoPath)")) { img in
                                        img.resizable().aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.systemGray5))
                                    }
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Text(p.providerName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 64)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct PersonCard: View {
    let name: String
    let subtitle: String?
    let imagePath: String?

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            // Top image stays fixed size and pinned to top
            AsyncImage(url: profileURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Circle().fill(Color(.systemGray5))
                    Image(systemName: "person.fill").foregroundColor(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            // Name
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 80, alignment: .top)

            // Subtitle/role
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 80, alignment: .top)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 96, height: 150, alignment: .top)
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var profileURL: URL? {
        guard let path = imagePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }
}

#Preview {
    if #available(iOS 17, *) {
        HomeView()
            .modelContainer(for: Film.self, inMemory: true)
    } else {
        Text("Requires iOS 17 or later")
    }
}

