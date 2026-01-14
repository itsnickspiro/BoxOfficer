//
//  TMDBModels.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation

// MARK: - TMDB Models
struct TMDBMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let popularity: Double
    let genreIds: [Int]
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case popularity
        case genreIds = "genre_ids"
    }
}

struct TMDBResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String?
    let runtime: Int?
    let budget: Int64
    let revenue: Int64
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let popularity: Double
    let genres: [TMDBGenre]
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, budget, revenue, genres
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity
    }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBCredits: Codable {
    let id: Int
    let cast: [TMDBCast]
    let crew: [TMDBCrew]
}

struct TMDBCast: Codable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

struct TMDBCrew: Codable, Identifiable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

// New Codable models for watch providers
struct TMDBWatchProvidersResponse: Codable {
    let results: [String: TMDBWatchProviderRegion]
}

struct TMDBWatchProviderRegion: Codable {
    let link: String?
    let flatrate: [TMDBWatchProvider]? // subscription
    let rent: [TMDBWatchProvider]?
    let buy: [TMDBWatchProvider]?
}

struct TMDBWatchProvider: Codable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }

    var id: Int { providerId }
}

// Added struct for person external IDs
struct TMDBPersonExternalIDs: Codable {
    let imdbID: String?
    enum CodingKeys: String, CodingKey {
        case imdbID = "imdb_id"
    }
}

// Added struct for movie external IDs
struct TMDBMovieExternalIDs: Codable {
    let imdbID: String?
    enum CodingKeys: String, CodingKey { case imdbID = "imdb_id" }
}

// Enhanced struct for OMDb response with box office data
struct OMDbResponse: Codable {
    struct Rating: Codable { let Source: String; let Value: String }
    let imdbID: String?
    let Ratings: [Rating]?
    let BoxOffice: String?
    let DVD: String?
    let Production: String?
    let Website: String?
    let Response: String?
    let Error: String?
}

enum TMDBError: Error {
    case invalidURL
    case noData
    case decodingError
}
