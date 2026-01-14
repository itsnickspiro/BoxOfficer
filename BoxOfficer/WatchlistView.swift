//
//  WatchlistView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Film> { $0.isInWatchlist }, 
           sort: \Film.dateAddedToWatchlist, 
           order: .reverse) private var watchlistFilms: [Film]
    @State private var searchText = ""
    
    private var filteredFilms: [Film] {
        if searchText.isEmpty {
            return watchlistFilms
        } else {
            return watchlistFilms.filter { film in
                film.title.localizedCaseInsensitiveContains(searchText) ||
                film.director.localizedCaseInsensitiveContains(searchText) ||
                film.genre.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if watchlistFilms.isEmpty {
                    emptyStateView
                } else {
                    watchlistContent
                }
            }
            .navigationTitle("Watchlist")
            .searchable(text: $searchText, prompt: "Search")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Films in Watchlist")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add films to your watchlist to keep track of movies you want to analyze.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var watchlistContent: some View {
        VStack(spacing: 0) {
            // Films list
            List {
                ForEach(filteredFilms) { film in
                    NavigationLink(destination: FilmDetailView(film: film)) {
                        WatchlistRowView(film: film)
                    }
                }
                .onDelete(perform: removeFromWatchlist)
            }
        }
    }
    
    private func removeFromWatchlist(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let film = filteredFilms[index]
                film.toggleWatchlist()
            }
        }
    }
    
    private func calculateAverageBudget() -> Int64? {
        let budgets = watchlistFilms.compactMap { $0.budget }
        guard !budgets.isEmpty else { return nil }
        return budgets.reduce(0, +) / Int64(budgets.count)
    }
    
    private func calculateTotalBoxOffice() -> Int64? {
        let boxOffices = watchlistFilms.compactMap { $0.boxOffice }
        guard !boxOffices.isEmpty else { return nil }
        return boxOffices.reduce(0, +)
    }
    
    private func calculateTotalProfit() -> Int64? {
        let profits = watchlistFilms.compactMap { $0.profit }
        guard !profits.isEmpty else { return nil }
        return profits.reduce(0, +)
    }
    

}

@available(iOS 17.0, *)
struct WatchlistRowView: View {
    let film: Film
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster
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
                    .lineLimit(2)
                
                if !film.director.isEmpty {
                    Text(film.director)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if film.budget != nil {
                        Label(film.formattedBudget, systemImage: "dollarsign.circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if film.boxOffice != nil {
                        Label(film.formattedBoxOffice, systemImage: "chart.bar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Rotten Tomatoes Scores
                if film.criticsScore != nil || film.audienceScore != nil {
                    RottenTomatoesView(film: film, size: 16, showLabels: false)
                }
            }
            
            Spacer()
            
            VStack {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.blue)
                
                if let profit = film.profit {
                    Text(film.formattedProfit)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(20)
    }
}

#Preview {
    if #available(iOS 17, *) {
        WatchlistView()
            .modelContainer(for: Film.self, inMemory: true)
    } else {
        // Fallback on earlier versions
    }
}

