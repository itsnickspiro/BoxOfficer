//
//  SecretsManager.swift
//  BoxOfficer
//
//  Secure secrets loader — reads API keys from Secrets.plist (gitignored).
//  Never commit Secrets.plist to source control.
//

import Foundation

final class SecretsManager {
    static let shared = SecretsManager()

    private let secrets: [String: Any]

    private init() {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            fatalError("Secrets.plist not found. Copy Secrets.plist.example to Secrets.plist and fill in your API keys.")
        }
        self.secrets = plist
    }

    func string(forKey key: String) -> String {
        guard let value = secrets[key] as? String, !value.isEmpty else {
            print("[SecretsManager] WARNING: Missing or empty key '\(key)' in Secrets.plist")
            return ""
        }
        return value
    }

    // Convenience accessors
    var tmdbAPIKey: String { string(forKey: "TMDB_API_KEY") }
    var traktClientID: String { string(forKey: "TRAKT_CLIENT_ID") }
    var traktClientSecret: String { string(forKey: "TRAKT_CLIENT_SECRET") }
    var omdbAPIKey: String { string(forKey: "OMDB_API_KEY") }
    var firebaseAPIKey: String { string(forKey: "FIREBASE_API_KEY") }
    var firebaseProjectID: String { string(forKey: "FIREBASE_PROJECT_ID") }
}
