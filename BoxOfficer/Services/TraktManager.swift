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
    
    // API Credentials provided by user
    private let clientID = "c5cdc42db378d38143b4c85b7c847bf95a74e9b77e29b4a61c94ee9485149459"
    private let clientSecret = "486f2574fb3df5e8e96ffc83c87491874aba287cce4a0a6b4519bea806126d64"
    
    private init() {}
    
    func getClientID() -> String {
        return clientID
    }
    
    // Secret is not currently needed for public read-only endpoints like Trending,
    // but useful to have for potential future auth flows.
    func getClientSecret() -> String {
        return clientSecret
    }
}
