//
//  CompareFilmsView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData
import Charts

@available(iOS 17.0, *)
struct CompareFilmsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var films: [Film]
    
    let selectedFilm: Film
    @State private var comparisonFilm: Film?
    @State private var searchText = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var suggestionResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showingMovieDetail: TMDBMovie?
    
    private var availableFilms: [Film] {
        films.filter { $0.id != selectedFilm.id }
    }
    
    private var filteredFilms: [Film] {
        if searchText.isEmpty {
            return availableFilms
        } else {
            return availableFilms.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let comparisonFilm = comparisonFilm {
                    ComparisonDetailView(
                        film1: selectedFilm,
                        film2: comparisonFilm,
                        onReset: { self.comparisonFilm = nil }
                    )
                } else {
                    filmSelectionView
                }
            }
            .navigationTitle("Compare Films")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $showingMovieDetail) { movie in
                TMDBMovieDetailView(movie: movie, buttonTitle: "Compare") { filmToAdd in
                    // When user adds a film from TMDB search, use it for comparison
                    comparisonFilm = filmToAdd
                    showingMovieDetail = nil
                }
            }
        }
    }
    
    private var filmSelectionView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Compare '\(selectedFilm.title)' with:")
                .font(.headline)
                .padding()
            
            // Search bar (matching HomeView style)
            VStack {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search movies on TMDB or your collection...", text: $searchText)
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
                            isSearchFieldFocused = false
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Results
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isSearchFieldFocused && !searchText.isEmpty {
                        // TMDB search suggestions (like HomeView)
                        ForEach(suggestionResults.prefix(20)) { movie in
                            TMDBMovieRowCompare(movie: movie) {
                                showingMovieDetail = movie
                            }
                        }
                    } else if !searchText.isEmpty {
                        // Combined results: TMDB search + local films
                        if isSearching {
                            ProgressView("Searching...")
                                .padding()
                        } else {
                            // TMDB Results
                            if !searchResults.isEmpty {
                                Section(header: Text("TMDB Results").font(.headline).padding(.top)) {
                                    ForEach(searchResults.prefix(10)) { movie in
                                        TMDBMovieRowCompare(movie: movie) {
                                            showingMovieDetail = movie
                                        }
                                    }
                                }
                            }
                            
                            // Local collection results
                            if !filteredFilms.isEmpty {
                                Section(header: Text("Your Collection").font(.headline).padding(.top)) {
                                    ForEach(filteredFilms) { film in
                                        LocalFilmRowCompare(film: film) {
                                            comparisonFilm = film
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Default: Show user's collection
                        ForEach(availableFilms) { film in
                            LocalFilmRowCompare(film: film) {
                                comparisonFilm = film
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // Search functions (matching HomeView)
    private func searchMovies() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let movies = try await TMDBService.shared.searchMovies(query: query)
                await MainActor.run {
                    self.searchResults = movies
                    self.suggestionResults = movies
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
            guard !Task.isCancelled else { return }
            await performSearch(for: trimmed)
        }
    }
    
    private func performSearch(for query: String) async {
        do {
            let movies = try await TMDBService.shared.searchMovies(query: query)
            await MainActor.run {
                self.searchResults = movies
                self.suggestionResults = movies
            }
        } catch {
            await MainActor.run { 
                self.suggestionResults = [] 
            }
        }
    }
}

// MARK: - Movie Row Components
@available(iOS 17.0, *)
struct TMDBMovieRowCompare: View {
    let movie: TMDBMovie
    let onTap: () -> Void
    
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
                            Image(systemName: "film.fill")
                                .foregroundColor(.secondary)
                        }
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let releaseDate = movie.releaseDate {
                        Text("Released: \(formatReleaseDate(releaseDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", movie.voteAverage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• TMDB")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    private var posterURL: URL? {
        guard let posterPath = movie.posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

@available(iOS 17.0, *)
struct LocalFilmRowCompare: View {
    let film: Film
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: film.posterURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "film.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(film.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !film.director.isEmpty {
                        Text(film.director)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(film.formattedBudget)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("→")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(film.formattedBoxOffice)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Your Collection")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
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

@available(iOS 17.0, *)
struct ComparisonDetailView: View {
    let film1: Film
    let film2: Film
    let onReset: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Film headers
                HStack {
                    FilmComparisonHeader(film: film1)
                    
                    Spacer()
                    
                    Text("VS")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    FilmComparisonHeader(film: film2)
                }
                .padding()
                
                // Financial comparison
                VStack(alignment: .leading, spacing: 16) {
                    Text("Financial Comparison")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    ComparisonMetric(
                        title: "Budget",
                        value1: film1.budget ?? 0,
                        value2: film2.budget ?? 0,
                        formatter: { formatCurrency($0) }
                    )
                    
                    ComparisonMetric(
                        title: "Box Office",
                        value1: film1.boxOffice ?? 0,
                        value2: film2.boxOffice ?? 0,
                        formatter: { formatCurrency($0) }
                    )
                    
                    ComparisonMetric(
                        title: "Profit",
                        value1: film1.profit ?? 0,
                        value2: film2.profit ?? 0,
                        formatter: { formatCurrency($0) },
                        allowNegative: true
                    )
                    
                    if let roi1 = film1.profitMargin, let roi2 = film2.profitMargin {
                        ComparisonMetric(
                            title: "ROI",
                            value1: Int64(roi1),
                            value2: Int64(roi2),
                            formatter: { "\(String(format: "%.1f", Double($0)))%" },
                            allowNegative: true
                        )
                    }
                }
                
                // Box Office Performance Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Box Office Performance")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Chart {
                        BarMark(
                            x: .value("Film", film1.title),
                            y: .value("Box Office", film1.boxOffice ?? 0)
                        )
                        .foregroundStyle(.blue)
                        
                        BarMark(
                            x: .value("Film", film2.title),
                            y: .value("Box Office", film2.boxOffice ?? 0)
                        )
                        .foregroundStyle(.orange)
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
                
                Button("Choose Different Film") {
                    onReset()
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
    }
    
    private func formatCurrency(_ amount: Int64) -> String {
        if abs(amount) >= 1_000_000_000 {
            let billions = Double(amount) / 1_000_000_000
            return "$\(String(format: "%.1f", billions))B"
        } else if abs(amount) >= 1_000_000 {
            let millions = Double(amount) / 1_000_000
            return "$\(String(format: "%.1f", millions))M"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        }
    }
}

@available(iOS 17.0, *)
struct FilmComparisonHeader: View {
    let film: Film
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: film.posterURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "film.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(film.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if let releaseDate = film.releaseDate {
                Text(releaseDate.formatted(.dateTime.year()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: 120)
    }
}

@available(iOS 17.0, *)
struct ComparisonMetric: View {
    let title: String
    let value1: Int64
    let value2: Int64
    let formatter: (Int64) -> String
    let allowNegative: Bool
    
    init(title: String, value1: Int64, value2: Int64, formatter: @escaping (Int64) -> String, allowNegative: Bool = false) {
        self.title = title
        self.value1 = value1
        self.value2 = value2
        self.formatter = formatter
        self.allowNegative = allowNegative
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            
            HStack {
                VStack {
                    Text(formatter(value1))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(value1 >= value2 ? .green : (allowNegative && value1 < 0 ? .red : .primary))
                    
                    if value1 >= value2 {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                VStack {
                    Text(formatter(value2))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(value2 >= value1 ? .green : (allowNegative && value2 < 0 ? .red : .primary))
                    
                    if value2 >= value1 {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

@available(iOS 17.0, *)
#Preview {
    CompareFilmsView(selectedFilm: Film(
        id: "1",
        title: "Avatar",
        budget: 350_000_000,
        boxOffice: 2_320_000_000
    ))
    .modelContainer(for: Film.self, inMemory: true)
}