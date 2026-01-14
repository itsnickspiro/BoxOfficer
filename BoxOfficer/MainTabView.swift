//
//  MainTabView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct MainTabView: View {
    var body: some View {
        TabView {
            if #available(iOS 17.0, *) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
            } else {
                // Fallback on earlier versions
            }
            
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "bookmark.fill")
                }
            
            NotificationsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        MainTabView()
            .modelContainer(for: Film.self, inMemory: true)
    } else {
        // Fallback on earlier versions
    }
}
