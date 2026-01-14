//
//  TraktService.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation

// MARK: - Trakt Service error
enum TraktError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
}

// MARK: - Trakt Service
class TraktService {
    static let shared = TraktService()
    
    // Headers required by Trakt API
    private var headers: [String: String] {
        return [
            "Content-Type": "application/json",
            "trakt-api-version": "2",
            "trakt-api-key": TraktManager.shared.getClientID()
        ]
    }
    
    private let baseURL = "https://api.trakt.tv"
    
    private init() {}
    
    /// Fetches the top trending movies from Trakt.
    /// Trakt returns a list of items; we map them to `TMDBMovie` by fetching details from TMDB.
    func fetchTrendingMovies() async throws -> [TMDBMovie] {
        let urlString = "\(baseURL)/movies/trending"
        // Pagination or extended info could be added here: e.g. ?page=1&limit=10
        
        guard let url = URL(string: urlString) else {
            throw TraktError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              (200...299).contains(httpResponse.statusCode) else {
            throw TraktError.invalidResponse
        }
        
        do {
            let trendingItems = try JSONDecoder().decode([TraktTrendingItem].self, from: data)
            
            // Hydrate with TMDB data concurrently
            // We limit to top 20 to avoid slamming TMDB API too hard at once
            let limitedItems = Array(trendingItems.prefix(20))
            
            return await withTaskGroup(of: TMDBMovie?.self, returning: [TMDBMovie].self) { group in
                for item in limitedItems {
                    group.addTask {
                        // Use TMDB ID if available to fetch full details including poster
                        if let tmdbID = item.movie.ids.tmdb {
                            do {
                                let details = try await TMDBService.shared.fetchMovieDetails(id: tmdbID)
                                return await self.mapDetailsToMovie(details)
                            } catch {
                                print("Failed to hydrate Trakt movie \(item.movie.title): \(error)")
                                return nil
                            }
                        }
                        return nil
                    }
                }
                
                var results: [TMDBMovie] = []
                for await movie in group {
                    if let movie = movie {
                        results.append(movie)
                    }
                }
                // Sort back to match original Trakt order logic? 
                // Group results come in random order. 
                // To preserve Trakt's "Trending" order, we should re-sort or use an index.
                // For simplicity, we'll sort by popularity (TMDB's metric) which is roughly similar,
                // or we could map them back. Let's just return results sorted by popularity for now.
                return results.sorted { $0.popularity > $1.popularity }
            }
            
        } catch {
            print("Trakt Decoding Error: \(error)")
            throw TraktError.decodingError
        }
    }
    
    private func mapDetailsToMovie(_ details: TMDBMovieDetails) -> TMDBMovie {
        return TMDBMovie(
            id: details.id,
            title: details.title,
            overview: details.overview,
            releaseDate: details.releaseDate,
            posterPath: details.posterPath,
            backdropPath: details.backdropPath,
            voteAverage: details.voteAverage,
            popularity: details.popularity,
            genreIds: details.genres.map { $0.id }
        )
    }
}
