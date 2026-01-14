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
                requestNotificationPermissions()
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
                
                NavigationLink("Browse Movies") {
                    // This would navigate to your main movie browsing view
                    Text("Navigate to Home to add movies")
                }
                .buttonStyle(.borderedProminent)
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
    
    // MARK: - Notification Permissions
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                // Permissions granted - could schedule background checks here
            }
        }
    }
    
    private func sendLocalNotification(for notification: BoxOfficeNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = UNNotificationSound.default
        
        // Create a unique identifier
        let identifier = notification.id.uuidString
        
        // Create a trigger for immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add the request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // MARK: - Financial Data Change Detection
    
    private func checkForFinancialUpdates() async {
        guard !watchlistFilms.isEmpty else { return }
        
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        
        var newNotifications: [BoxOfficeNotification] = []
        
        // Check each watchlist film for financial data changes
        for film in watchlistFilms {
            do {
                // Get latest data from TMDB API
                if let latestData = try await fetchLatestFinancialData(for: film) {
                    let changes = detectFinancialChanges(original: film, updated: latestData)
                    
                    for change in changes {
                        let notification = createNotificationForChange(change, film: film)
                        newNotifications.append(notification)
                        
                        // Update the film's data in the model
                        updateFilmData(film, with: latestData)
                    }
                }
            } catch {
                print("Error fetching data for \(film.title): \(error)")
                // Could add error notification here if needed
            }
        }
        
        // Add new notifications and store them
        for notification in newNotifications {
            notifications.insert(notification, at: 0)
            storeNotification(notification)
            
            // Send local push notification
            sendLocalNotification(for: notification)
        }
        
        // Sort notifications by timestamp
        notifications.sort { $0.timestamp > $1.timestamp }
    }
    
    private func fetchLatestFinancialData(for film: Film) async throws -> FinancialData? {
        // Get the TMDb ID from the film
        guard let tmdbID = film.tmdbID ?? Int(film.id) else { return nil }
        
        // Fetch the latest movie details from TMDB API
        let details = try await TMDBService.shared.fetchMovieDetails(id: tmdbID)
        
        return FinancialData(
            budget: details.budget > 0 ? Int64(details.budget) : nil,
            boxOffice: details.revenue > 0 ? Int64(details.revenue) : nil,
            domesticBoxOffice: nil, // TMDB doesn't provide domestic/international split in basic details
            internationalBoxOffice: nil
        )
    }
    
    private func detectFinancialChanges(original: Film, updated: FinancialData) -> [FinancialChange] {
        var changes: [FinancialChange] = []
        
        // Check budget changes
        if let originalBudget = original.budget, 
           let updatedBudget = updated.budget,
           originalBudget != updatedBudget {
            changes.append(.budget(from: originalBudget, to: updatedBudget))
        }
        
        // Check box office changes
        if let originalBoxOffice = original.boxOffice,
           let updatedBoxOffice = updated.boxOffice,
           originalBoxOffice != updatedBoxOffice {
            changes.append(.boxOffice(from: originalBoxOffice, to: updatedBoxOffice))
        }
        
        // Check domestic box office changes
        if let originalDomestic = original.domesticBoxOffice,
           let updatedDomestic = updated.domesticBoxOffice,
           originalDomestic != updatedDomestic {
            changes.append(.domesticBoxOffice(from: originalDomestic, to: updatedDomestic))
        }
        
        // Check international box office changes
        if let originalInternational = original.internationalBoxOffice,
           let updatedInternational = updated.internationalBoxOffice,
           originalInternational != updatedInternational {
            changes.append(.internationalBoxOffice(from: originalInternational, to: updatedInternational))
        }
        
        return changes
    }
    
    private func createNotificationForChange(_ change: FinancialChange, film: Film) -> BoxOfficeNotification {
        let (title, message, type) = change.notificationContent(for: film.title)
        
        return BoxOfficeNotification(
            id: UUID(),
            title: title,
            message: message,
            type: type,
            filmId: film.id,
            timestamp: Date(),
            isRead: false
        )
    }
    
    @MainActor
    private func updateFilmData(_ film: Film, with data: FinancialData) {
        if let budget = data.budget { film.budget = budget }
        if let boxOffice = data.boxOffice { film.boxOffice = boxOffice }
        if let domestic = data.domesticBoxOffice { film.domesticBoxOffice = domestic }
        if let international = data.internationalBoxOffice { film.internationalBoxOffice = international }
        
        try? modelContext.save()
    }
    
    // MARK: - Notification Storage (UserDefaults for simplicity)
    
    private func loadStoredNotifications() {
        if let data = UserDefaults.standard.data(forKey: "StoredNotifications"),
           let decoded = try? JSONDecoder().decode([BoxOfficeNotification].self, from: data) {
            notifications = decoded.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    private func storeNotification(_ notification: BoxOfficeNotification) {
        var stored = notifications
        stored.append(notification)
        saveNotifications(stored)
    }
    
    private func updateStoredNotification(_ notification: BoxOfficeNotification) {
        saveNotifications(notifications)
    }
    
    private func removeStoredNotification(_ notification: BoxOfficeNotification) {
        saveNotifications(notifications.filter { $0.id != notification.id })
    }
    
    private func saveNotifications(_ notificationsToSave: [BoxOfficeNotification]) {
        if let encoded = try? JSONEncoder().encode(notificationsToSave) {
            UserDefaults.standard.set(encoded, forKey: "StoredNotifications")
        }
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
