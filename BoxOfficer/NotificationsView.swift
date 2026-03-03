//
//  NotificationsView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@available(iOS 17.0, *)
struct NotificationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Film> { film in 
        film.isInWatchlist == true 
    }) private var watchlistFilms: [Film]
    
    @State private var notifications: [BoxOfficeNotification] = []
    @State private var showingSettings = false
    @State private var isCheckingForUpdates = false
    
    var body: some View {
        NavigationView {
            Group {
                if notifications.isEmpty && !isCheckingForUpdates {
                    emptyStateView
                } else if isCheckingForUpdates {
                    loadingView
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NotificationSettingsView()
            }
            .onAppear {
                loadStoredNotifications()
            }
            .refreshable {
                await checkForFinancialUpdates()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Notifications")
                .font(.title2)
                .fontWeight(.semibold)
            
            if watchlistFilms.isEmpty {
                Text("Add movies to your watchlist to receive notifications about box office updates and financial data changes.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Text("Switch to the Home tab to browse and add movies to your watchlist.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("We'll notify you when financial data changes for your \(watchlistFilms.count) watchlist movies.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button("Check for Updates") {
                    Task {
                        await checkForFinancialUpdates()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingForUpdates)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Checking for financial updates...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Comparing current data with latest API information for your watchlist movies.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var notificationsList: some View {
        List {
            ForEach(notifications) { notification in
                NotificationRowView(notification: notification) {
                    markAsRead(notification)
                }
            }
            .onDelete(perform: deleteNotifications)
        }
    }
    
    private func deleteNotifications(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let notification = notifications[index]
                removeStoredNotification(notification)
            }
            notifications.remove(atOffsets: offsets)
        }
    }
    
    private func markAsRead(_ notification: BoxOfficeNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            updateStoredNotification(notifications[index])
        }
    }
    
    // MARK: - Financial Data Change Detection

    private func checkForFinancialUpdates() async {
        guard !watchlistFilms.isEmpty else { return }

        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        let newNotifications = await NotificationCheckService.shared.checkForUpdates(
            films: watchlistFilms,
            context: modelContext
        )

        for notification in newNotifications {
            notifications.insert(notification, at: 0)
        }
        notifications.sort { $0.timestamp > $1.timestamp }
    }

    // MARK: - Notification Storage

    private func loadStoredNotifications() {
        notifications = NotificationCheckService.shared.loadStoredNotifications()
    }

    private func updateStoredNotification(_ notification: BoxOfficeNotification) {
        NotificationCheckService.shared.saveNotifications(notifications)
    }

    private func removeStoredNotification(_ notification: BoxOfficeNotification) {
        NotificationCheckService.shared.saveNotifications(
            notifications.filter { $0.id != notification.id }
        )
    }
}

// MARK: - Supporting Types

struct FinancialData {
    let budget: Int64?
    let boxOffice: Int64?
    let domesticBoxOffice: Int64?
    let internationalBoxOffice: Int64?
}

enum FinancialChange {
    case budget(from: Int64, to: Int64)
    case boxOffice(from: Int64, to: Int64)
    case domesticBoxOffice(from: Int64, to: Int64)
    case internationalBoxOffice(from: Int64, to: Int64)
    
    func notificationContent(for filmTitle: String) -> (title: String, message: String, type: BoxOfficeNotification.NotificationType) {
        switch self {
        case .budget(let from, let to):
            let change = to - from
            let changeText = change > 0 ? "increased" : "decreased"
            return (
                title: "Budget Update 💰",
                message: "\(filmTitle)'s budget has \(changeText) by \(Formatters.currency(amount: abs(change)))",
                type: .update
            )
            
        case .boxOffice(let from, let to):
            let change = to - from
            let changeText = change > 0 ? "increased" : "decreased"
            return (
                title: "Box Office Update 📊",
                message: "\(filmTitle)'s total box office has \(changeText) by \(Formatters.currency(amount: abs(change)))",
                type: .milestone
            )
            
        case .domesticBoxOffice(let from, let to):
            let change = to - from
            let changeText = change > 0 ? "increased" : "decreased"
            return (
                title: "Domestic Box Office Update 🇺🇸",
                message: "\(filmTitle)'s domestic earnings have \(changeText) by \(Formatters.currency(amount: abs(change)))",
                type: .update
            )
            
        case .internationalBoxOffice(let from, let to):
            let change = to - from
            let changeText = change > 0 ? "increased" : "decreased"
            return (
                title: "International Box Office Update 🌍",
                message: "\(filmTitle)'s international earnings have \(changeText) by \(Formatters.currency(amount: abs(change)))",
                type: .update
            )
        }
    }
}

struct NotificationRowView: View {
    let notification: BoxOfficeNotification
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: notification.type.iconName)
                .font(.title3)
                .foregroundColor(notification.type.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(notification.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if !notification.isRead {
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                        
                        Text("New")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct BoxOfficeNotification: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let message: String
    let type: NotificationType
    let filmId: String?
    let timestamp: Date
    var isRead: Bool
    
    enum NotificationType: String, CaseIterable, Codable {
        case milestone, update, analysis, trend, alert
        
        var iconName: String {
            switch self {
            case .milestone: return "star.fill"
            case .update: return "bell.fill"
            case .analysis: return "chart.line.uptrend.xyaxis"
            case .trend: return "arrow.trending.up"
            case .alert: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .milestone: return .yellow
            case .update: return .blue
            case .analysis: return .purple
            case .trend: return .green
            case .alert: return .red
            }
        }
    }
}

@available(iOS 17.0, *)
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("enableFinancialUpdates") private var enableFinancialUpdates = true
    @AppStorage("enableBudgetChanges") private var enableBudgetChanges = true
    @AppStorage("enableBoxOfficeChanges") private var enableBoxOfficeChanges = true
    @AppStorage("enableDomesticChanges") private var enableDomesticChanges = false
    @AppStorage("enableInternationalChanges") private var enableInternationalChanges = false
    @AppStorage("updateFrequency") private var updateFrequency = "Daily"
    
    @available(iOS 17.0, *)
    var body: some View {
        NavigationView {
            Form {
                Section("Financial Data Notifications") {
                    Toggle("Enable Financial Updates", isOn: $enableFinancialUpdates)
                        .onChange(of: enableFinancialUpdates) { _, newValue in
                            if !newValue {
                                // Disable all sub-options when main toggle is off
                                enableBudgetChanges = false
                                enableBoxOfficeChanges = false
                                enableDomesticChanges = false
                                enableInternationalChanges = false
                            }
                        }
                    
                    if enableFinancialUpdates {
                        Toggle("Budget Changes", isOn: $enableBudgetChanges)
                        Toggle("Box Office Changes", isOn: $enableBoxOfficeChanges)
                        Toggle("Domestic Box Office", isOn: $enableDomesticChanges)
                        Toggle("International Box Office", isOn: $enableInternationalChanges)
                    }
                }
                
                Section("Update Frequency") {
                    Picker("Check for Updates", selection: $updateFrequency) {
                        Text("Hourly").tag("Hourly")
                        Text("Daily").tag("Daily")
                        Text("Weekly").tag("Weekly")
                    }
                }
                
                Section("About") {
                    Text("Notifications are only sent for movies in your watchlist when their financial data changes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        NotificationsView()
            .modelContainer(for: Film.self, inMemory: true)
    } else {
        // Fallback on earlier versions
    }
}
