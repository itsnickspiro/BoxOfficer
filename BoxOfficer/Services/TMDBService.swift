//
//  TMDBService.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation

// MARK: - TMDB Service
class TMDBService {
    static let shared = TMDBService()
    private let apiKey = TMDBManager.shared.getAPIKey()
    private let baseURL = "https://api.themoviedb.org/3"
    
    private init() {}
    
    func fetchNowPlayingMovies() async throws -> [TMDBMovie] {
        let urlString = "\(baseURL)/movie/now_playing?api_key=\(apiKey)&language=en-US&page=1"
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return response.results
    }
    
    func fetchDigitalReleases() async throws -> [TMDBMovie] {
        // TMDB Discover: filter for digital/streaming availability on today's date for major US providers
        // Provider IDs (TMDB): Netflix=8, Hulu=15, Disney+=337, Max(HBO Max)=384, Amazon Prime Video=119, Apple TV+=350
        let providerIDs = [8, 15, 337, 384, 119, 350]
        let providersParam = providerIDs.map(String.init).joined(separator: "|")
        let today = {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: Date())
        }()
        var urlString = "\(baseURL)/discover/movie?api_key=\(apiKey)"
        urlString += "&language=en-US"
        urlString += "&sort_by=popularity.desc"
        urlString += "&watch_region=US"
        urlString += "&with_watch_monetization_types=flatrate"
        urlString += "&with_watch_providers=\(providersParam)"
        // Ensure not in the future: only items released on or before today
        urlString += "&release_date.lte=\(today)"
        // Prefer digital release type (4) if available
        urlString += "&with_release_type=4"
        urlString += "&vote_count.gte=50" // Filter out very obscure items
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return response.results
    }
    
    func fetchUpcomingTheatrical() async throws -> [TMDBMovie] {
        // Discover upcoming theatrical releases (release types 2|3) with release_date >= today
        let today = {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: Date())
        }()
        var urlString = "\(baseURL)/discover/movie?api_key=\(apiKey)"
        urlString += "&language=en-US"
        urlString += "&sort_by=popularity.desc"
        urlString += "&region=US"
        urlString += "&with_release_type=2|3"
        urlString += "&release_date.gte=\(today)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return response.results
    }

    func fetchUpcomingDigital() async throws -> [TMDBMovie] {
        // Discover upcoming digital releases (release type 4) with release_date >= today and major US providers
        let providerIDs = [8, 15, 337, 384, 119, 350]
        let providersParam = providerIDs.map(String.init).joined(separator: "|")
        let today = {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: Date())
        }()
        var urlString = "\(baseURL)/discover/movie?api_key=\(apiKey)"
        urlString += "&language=en-US"
        urlString += "&sort_by=popularity.desc"
        urlString += "&watch_region=US"
        urlString += "&with_watch_monetization_types=flatrate"
        urlString += "&with_watch_providers=\(providersParam)"
        urlString += "&with_release_type=4"
        urlString += "&release_date.gte=\(today)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return response.results
    }
    
    func fetchTrendingMovies() async throws -> [TMDBMovie] {
        let urlString = "\(baseURL)/trending/movie/week?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return response.results
    }

    func fetchTopRated(region: String?, pages: Int) async throws -> [TMDBMovie] {
        var all: [TMDBMovie] = []
        for page in 1...max(1, pages) {
            var urlString = "\(baseURL)/movie/top_rated?api_key=\(apiKey)&language=en-US&page=\(page)"
            if let region = region { urlString += "&region=\(region)" }
            guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
            all.append(contentsOf: response.results)
        }
        return all
    }
    
    func fetchTopGrossing(pages: Int) async throws -> [TMDBMovie] {
        var all: [TMDBMovie] = []
        for page in 1...max(1, pages) {
            var urlString = "\(baseURL)/discover/movie?api_key=\(apiKey)&sort_by=revenue.desc&page=\(page)"
            // Optionally filter to popular titles to avoid obscure entries
            urlString += "&vote_count.gte=500"
            guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
            all.append(contentsOf: response.results)
        }
        return all
    }
    
    func searchMovies(query: String) async throws -> [TMDBMovie] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&language=en-US&query=\(encodedQuery)&page=1"
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return response.results
    }
    
    func fetchMovieDetails(id: Int) async throws -> TMDBMovieDetails {
        let urlString = "\(baseURL)/movie/\(id)?api_key=\(apiKey)&language=en-US"
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let movieDetails = try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
        return movieDetails
    }
    
    func fetchMovieCredits(id: Int) async throws -> TMDBCredits {
        let urlString = "\(baseURL)/movie/\(id)/credits?api_key=\(apiKey)&language=en-US"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let credits = try JSONDecoder().decode(TMDBCredits.self, from: data)
        return credits
    }
    
    // New method to fetch watch providers for a movie id (US region)
    func fetchWatchProviders(id: Int) async throws -> TMDBWatchProviderRegion? {
        let urlString = "\(baseURL)/movie/\(id)/watch/providers?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBWatchProvidersResponse.self, from: data)
        // Prefer US region
        return response.results["US"]
    }
    
    // Added method to fetch person external IDs
    func fetchPersonExternalIDs(id: Int) async throws -> TMDBPersonExternalIDs {
        let urlString = "\(baseURL)/person/\(id)/external_ids?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let ids = try JSONDecoder().decode(TMDBPersonExternalIDs.self, from: data)
        return ids
    }
    
    // Added method to fetch movie external IDs
    func fetchMovieExternalIDs(id: Int) async throws -> TMDBMovieExternalIDs {
        let urlString = "\(baseURL)/movie/\(id)/external_ids?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let ids = try JSONDecoder().decode(TMDBMovieExternalIDs.self, from: data)
        return ids
    }
    
    // Enhanced method to fetch Rotten Tomatoes score and box office data via OMDb
    func fetchRottenTomatoesScore(imdbID: String) async throws -> Int? {
        let omdbKey = TMDBManager.shared.getOMDbAPIKey()
        guard !omdbKey.isEmpty else { return nil }
        guard let url = URL(string: "https://www.omdbapi.com/?i=\(imdbID)&apikey=\(omdbKey)") else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(OMDbResponse.self, from: data)
        if let ratings = resp.Ratings, let rt = ratings.first(where: { $0.Source == "Rotten Tomatoes" }) {
            let digits = rt.Value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")
            if let val = Int(digits) { return val }
        }
        return nil
    }
    
    // New method to fetch detailed movie data from OMDb including box office
    func fetchOMDbMovieDetails(imdbID: String) async throws -> OMDbResponse? {
        let omdbKey = TMDBManager.shared.getOMDbAPIKey()
        guard !omdbKey.isEmpty else { return nil }
        guard let url = URL(string: "https://www.omdbapi.com/?i=\(imdbID)&apikey=\(omdbKey)") else { throw TMDBError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(OMDbResponse.self, from: data)
        guard resp.Response == "True" else { return nil }
        return resp
    }

    func fetchInTheatersTheatrical() async throws -> [TMDBMovie] {
        // Use Discover API constrained to theatrical release types (2|3) for US region
        // Expand window to the last 8 weeks to better reflect "now playing"
        let today: String = {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: Date())
        }()
        let eightWeeksAgo: String = {
            let cal = Calendar(identifier: .gregorian)
            let start = cal.date(byAdding: .day, value: -56, to: Date()) ?? Date()
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: start)
        }()

        var all: [TMDBMovie] = []
        // Pull several pages to improve coverage
        for page in 1...5 {
            var urlString = "\(baseURL)/discover/movie?api_key=\(apiKey)"
            urlString += "&language=en-US"
            urlString += "&region=US"
            urlString += "&sort_by=popularity.desc"
            urlString += "&with_release_type=2|3" // Theatrical and limited theatrical
            urlString += "&primary_release_date.gte=\(eightWeeksAgo)" // Rolling 8 weeks
            urlString += "&primary_release_date.lte=\(today)" // Released by today
            urlString += "&page=\(page)"
            // Optional: reduce very obscure entries
            urlString += "&vote_count.gte=25"
            guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
            all.append(contentsOf: response.results)
        }

        // De-duplicate by id
        let unique = Dictionary(grouping: all, by: { $0.id }).compactMap { $0.value.first }
        return unique
    }
}
