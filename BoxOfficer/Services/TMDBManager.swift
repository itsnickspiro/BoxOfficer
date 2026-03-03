//
//  TMDBManager.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation

// MARK: - TMDB API Manager
class TMDBManager {
    static let shared = TMDBManager()

    private let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String, !key.isEmpty else {
            fatalError("TMDB_API_KEY not set in Info.plist. Add it via Secrets.xcconfig.")
        }
        return key
    }()

    private let omdbAPIKey: String = {
        return Bundle.main.object(forInfoDictionaryKey: "OMDB_API_KEY") as? String ?? ""
    }()

    private init() {}
    func validateAPIConnection() async -> Bool {
        let urlString = "https://api.themoviedb.org/3/configuration?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    func getAPIKey() -> String {
        return apiKey
    }

    /// Returns the configured OMDb API key, if any. Used for fetching Rotten Tomatoes scores via OMDb.
    func getOMDbAPIKey() -> String {
        return omdbAPIKey
    }
}
