//
//  TraktModels.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation

// MARK: - Trakt Models

struct TraktIds: Codable {
    let trakt: Int
    let slug: String
    let imdb: String?
    let tmdb: Int?
}

struct TraktMovie: Codable {
    let title: String
    let year: Int?
    let ids: TraktIds
}

struct TraktTrendingItem: Codable {
    let watchers: Int
    let movie: TraktMovie
}
