//
//  Film.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class Film {
    var tmdbID: Int? // Store the numeric TMDB ID for reliable fetching
    var id: String
    var title: String
    var releaseDate: Date?
    var budget: Int64? // Budget in dollars
    var boxOffice: Int64? // Total box office earnings in dollars
    var domesticBoxOffice: Int64?
    var internationalBoxOffice: Int64?
    var runtime: Int? // Runtime in minutes
    var genre: String
    var director: String
    var posterURL: String?
    var overview: String
    var isInWatchlist: Bool
    var dateAddedToWatchlist: Date?
    
    // Rotten Tomatoes Scores
    var criticsScore: Int? // Critics score (0-100)
    var audienceScore: Int? // Audience score (0-100)
    var imdbRating: Double? // IMDb rating (0.0-10.0)
    
    // Computed properties
    var profit: Int64? {
        guard let budget = budget, let boxOffice = boxOffice else { return nil }
        return boxOffice - budget
    }
    
    var profitMargin: Double? {
        guard let budget = budget, let boxOffice = boxOffice, budget > 0 else { return nil }
        return Double(boxOffice - budget) / Double(budget) * 100
    }
    
    var formattedBudget: String {
        guard let budget = budget else { return "Unknown" }
        return Formatters.currency(amount: budget)
    }
    
    var formattedBoxOffice: String {
        guard let boxOffice = boxOffice else { return "Unknown" }
        return Formatters.currency(amount: boxOffice)
    }
    
    var formattedProfit: String {
        guard let profit = profit else { return "Unknown" }
        let prefix = profit >= 0 ? "+" : ""
        return prefix + Formatters.currency(amount: profit)
    }
    
    // Rotten Tomatoes computed properties
    var criticsRatingImage: String? {
        guard let score = criticsScore else { return nil }
        if score >= 75 {
            return "Certified Fresh" // Your custom image name
        } else if score >= 60 {
            return "Fresh" // Your custom image name
        } else {
            return "Rotten" // Your custom image name
        }
    }
    
    var audienceRatingImage: String? {
        guard let score = audienceScore else { return nil }
        if score >= 60 {
            return "Positive Audience" // Your custom image name
        } else {
            return "Negative Audience" // Your custom image name
        }
    }
    
    init(id: String, tmdbID: Int? = nil, title: String, releaseDate: Date? = nil, budget: Int64? = nil, 
         boxOffice: Int64? = nil, domesticBoxOffice: Int64? = nil, 
         internationalBoxOffice: Int64? = nil, runtime: Int? = nil, 
         genre: String = "", director: String = "", posterURL: String? = nil, 
         overview: String = "", criticsScore: Int? = nil, audienceScore: Int? = nil,
         imdbRating: Double? = nil) {
        self.id = id
        self.tmdbID = tmdbID
        self.title = title
        self.releaseDate = releaseDate
        self.budget = budget
        self.boxOffice = boxOffice
        self.domesticBoxOffice = domesticBoxOffice
        self.internationalBoxOffice = internationalBoxOffice
        self.runtime = runtime
        self.genre = genre
        self.director = director
        self.posterURL = posterURL
        self.overview = overview
        self.isInWatchlist = false
        self.dateAddedToWatchlist = nil
        self.criticsScore = criticsScore
        self.audienceScore = audienceScore
        self.imdbRating = imdbRating
    }
}

@available(iOS 17.0, *)
extension Film {
    func toggleWatchlist() {
        isInWatchlist.toggle()
        dateAddedToWatchlist = isInWatchlist ? Date() : nil
    }
}