//
//  TraktManager.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation

// MARK: - Trakt API Manager
class TraktManager {
    static let shared = TraktManager()

    private let clientID: String
    private let clientSecret: String

    private init() {
        self.clientID = SecretsManager.shared.traktClientID
        self.clientSecret = SecretsManager.shared.traktClientSecret
    }

    func getClientID() -> String {
        return clientID
    }

    // Secret is not currently needed for public read-only endpoints like Trending,
    // but useful to have for potential future auth flows.
    func getClientSecret() -> String {
        return clientSecret
    }
}
