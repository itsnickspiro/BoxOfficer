//
//  FilmRowView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI

@available(iOS 17.0, *)
struct FilmRowView: View {
    let film: Film
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster placeholder or image
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
                            .font(.title2)
                    )
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(film.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if film.isInWatchlist {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                if !film.director.isEmpty {
                    Text("Directed by \(film.director)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    if let releaseDate = film.releaseDate {
                        Text(releaseDate, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if !film.genre.isEmpty {
                        Text("• \(film.genre)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Budget")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(film.formattedBudget)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Box Office")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(film.formattedBoxOffice)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Profit")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(film.formattedProfit)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(profitColor)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var profitColor: Color {
        guard let profit = film.profit else { return .primary }
        return profit >= 0 ? .green : .red
    }
}

#Preview {
    List {
        if #available(iOS 17, *) {
            FilmRowView(film: Film(
                id: "1",
                title: "Avatar: The Way of Water",
                releaseDate: Date(),
                budget: 350_000_000,
                boxOffice: 2_320_000_000,
                genre: "Sci-Fi",
                director: "James Cameron",
                overview: "A sequel to Avatar"
            ))
        } else {
            // Fallback on earlier versions
        }
        
        if #available(iOS 17, *) {
            FilmRowView(film: Film(
                id: "2",
                title: "The Flash",
                releaseDate: Date(),
                budget: 300_000_000,
                boxOffice: 270_000_000,
                genre: "Superhero",
                director: "Andy Muschietti",
                overview: "DC superhero film"
            ))
        } else {
            // Fallback on earlier versions
        }
    }
}
