//
//  FilmDetailView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import Charts
import SwiftData

@available(iOS 17.0, *)
struct FilmDetailView: View {
    @Bindable var film: Film
    @Environment(\.modelContext) private var modelContext
    @State private var showingCompareView = false
    @State private var chartViewMode: ChartViewMode = .breakdown
    
    enum ChartViewMode {
        case breakdown
        case performance
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with poster and basic info
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: URL(string: film.posterURL ?? "")) { image in
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
                        Text(film.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if !film.director.isEmpty {
                            Label(film.director, systemImage: "person.fill")
                                .font(.subheadline)
                        }
                        
                        if let releaseDate = film.releaseDate {
                            Label(releaseDate.formatted(date: .abbreviated, time: .omitted), 
                                  systemImage: "calendar")
                                .font(.subheadline)
                        }
                        
                        if !film.genre.isEmpty {
                            Label(film.genre, systemImage: "tag.fill")
                                .font(.subheadline)
                        }
                        
                        if let runtime = film.runtime {
                            Label("\(runtime) minutes", systemImage: "clock.fill")
                                .font(.subheadline)
                        }
                        
                        // Movie Ratings Row (like streaming services)
                        if film.imdbRating != nil || film.criticsScore != nil || film.audienceScore != nil {
                            MovieRatingsRow(film: film)
                        }
                        
                        Button(film.isInWatchlist ? "Remove from Watchlist" : "Add to Watchlist") {
                            withAnimation {
                                film.isInWatchlist.toggle()
                                film.dateAddedToWatchlist = film.isInWatchlist ? Date() : nil
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(film.isInWatchlist ? .red : .blue)
                    }
                    
                    Spacer()
                }
                .padding()
                
                // Financial Overview
                VStack(alignment: .leading, spacing: 16) {
                    Text("Financial Performance")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        FinancialCard(
                            title: "Budget",
                            value: film.formattedBudget,
                            icon: "dollarsign.square.fill",
                            color: .blue
                        )
                        
                        FinancialCard(
                            title: "Box Office",
                            value: film.formattedBoxOffice,
                            icon: "chart.bar.xaxis",
                            color: .green
                        )
                        
                        FinancialCard(
                            title: "Domestic",
                            value: film.domesticBoxOffice?.formatted(.currency(code: "USD")) ?? "Unknown",
                            icon: "flag.fill",
                            color: .orange
                        )
                        
                        FinancialCard(
                            title: "International",
                            value: film.internationalBoxOffice?.formatted(.currency(code: "USD")) ?? "Unknown",
                            icon: "globe",
                            color: .purple
                        )
                        
                        FinancialCard(
                            title: "Profit",
                            value: film.formattedProfit,
                            icon: film.profit ?? 0 >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                            color: film.profit ?? 0 >= 0 ? .green : .red
                        )
                        
                        if let profitMargin = film.profitMargin {
                            FinancialCard(
                                title: "ROI",
                                value: "\(String(format: "%.1f", profitMargin))%",
                                icon: "percent",
                                color: profitMargin >= 0 ? .green : .red
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Box Office Analysis Section
                if film.domesticBoxOffice != nil || film.internationalBoxOffice != nil || film.boxOffice != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Box Office Analysis")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Picker("View", selection: $chartViewMode) {
                                Text("Breakdown").tag(ChartViewMode.breakdown)
                                Text("Performance").tag(ChartViewMode.performance)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                        .padding(.horizontal)
                        
                        if chartViewMode == .breakdown {
                            // Existing Pie Chart Breakdown
                            if #available(iOS 16.0, *) {
                                Chart {
                                    if let domestic = film.domesticBoxOffice {
                                        SectorMark(
                                            angle: .value("Revenue", domestic),
                                            innerRadius: .ratio(0.618),
                                            angularInset: 1.5
                                        )
                                        .foregroundStyle(.blue)
                                        .opacity(0.6)
                                    }
                                    
                                    if let international = film.internationalBoxOffice {
                                        SectorMark(
                                            angle: .value("Revenue", international),
                                            innerRadius: .ratio(0.618),
                                            angularInset: 1.5
                                        )
                                        .foregroundStyle(.orange)
                                        .opacity(0.6)
                                    }
                                }
                                .frame(height: 200)
                                .padding(.horizontal)
                            } else {
                                // Fallback on earlier versions - simple text breakdown
                                VStack(alignment: .leading, spacing: 8) {
                                    if let domestic = film.domesticBoxOffice {
                                        HStack {
                                            Text("Domestic:")
                                            Spacer()
                                            Text(domestic.formatted(.currency(code: "USD")))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    
                                    if let international = film.internationalBoxOffice {
                                        HStack {
                                            Text("International:")
                                            Spacer()
                                            Text(international.formatted(.currency(code: "USD")))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            // Legend for Pie Chart
                            HStack {
                                if film.domesticBoxOffice != nil {
                                    HStack {
                                        Circle()
                                            .fill(.blue)
                                            .frame(width: 12, height: 12)
                                        Text("Domestic")
                                            .font(.caption)
                                    }
                                }
                                
                                if film.internationalBoxOffice != nil {
                                    HStack {
                                        Circle()
                                            .fill(.orange)
                                            .frame(width: 12, height: 12)
                                        Text("International")
                                            .font(.caption)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                        } else {
                            // New Performance History Chart
                            if #available(iOS 16.0, *) {
                                BoxOfficeHistoryChart(
                                    budget: film.budget ?? 0,
                                    totalBoxOffice: film.boxOffice ?? 0,
                                    releaseDate: film.releaseDate
                                )
                                .padding(.horizontal)
                                .transition(.opacity)
                            } else {
                                ContentUnavailableView("Feature Unavailable", systemImage: "chart.xyaxis.line", description: Text("Graph is only available on iOS 16+"))
                                    .padding()
                            }
                        }
                    }
                }
                
                // Overview
                if !film.overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overview")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(film.overview)
                            .font(.body)
                    }
                    .padding()
                }
                
                // Cast & Crew (from TMDB when available)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cast")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<6) { _ in
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 72, height: 72)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 80, height: 10)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 60, height: 8)
                                }
                                .padding(8)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }

                    Text("Crew")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<6) { _ in
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 72, height: 72)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 80, height: 10)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 60, height: 8)
                                }
                                .padding(8)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }

                    Text("Cast and crew will appear here when added from TMDB.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Compare") {
                    showingCompareView = true
                }
            }
        }
        .sheet(isPresented: $showingCompareView) {
            CompareFilmsView(selectedFilm: film)
        }
    }
}

@available(iOS 17.0, *)
struct MovieRatingsRow: View {
    let film: Film
    
    var body: some View {
        HStack(spacing: 12) {
            // IMDb Rating - just star and rating
            if let imdbRating = film.imdbRating {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        .frame(height: 12)
                    Text("\(String(format: "%.1f", imdbRating))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
            
            // Rotten Tomatoes Scores - clean icons with %
            if film.criticsScore != nil || film.audienceScore != nil {
                RottenTomatoesView(film: film, size: 12, showLabels: false)
            }
        }
    }
}

struct FinancialCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        NavigationView {
            FilmDetailView(film: Film(
                id: "1",
                title: "Avatar: The Way of Water",
                releaseDate: Date(),
                budget: 350_000_000,
                boxOffice: 2_320_000_000,
                domesticBoxOffice: 684_075_767,
                internationalBoxOffice: 1_635_924_233,
                runtime: 192,
                genre: "Sci-Fi",
                director: "James Cameron",
                overview: "Set more than a decade after the events of the first film, Avatar: The Way of Water begins to tell the story of the Sully family, the trouble that follows them, the lengths they go to keep each other safe, the battles they fight to stay alive, and the tragedies they endure.",
                criticsScore: 76,
                audienceScore: 92,
                imdbRating: 7.6
            ))
        }
        .modelContainer(for: Film.self, inMemory: true)
    } else {
        // Fallback on earlier versions
    }
}
