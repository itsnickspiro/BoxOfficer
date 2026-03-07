//
//  MainTabView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
                            HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                        
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "bookmark.fill")
                }

            CompareTabView()
                .tabItem {
                    Label("Compare", systemImage: "chart.bar.xaxis")
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
            MainTabView()
            .modelContainer(for: Film.self, inMemory: true)
    }
