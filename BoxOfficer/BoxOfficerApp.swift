//
//  BoxOfficerApp.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks

@main
struct BoxOfficerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Film.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        requestNotificationPermissions()
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    scheduleBackgroundRefresh()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Notification Permissions

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Background Tasks

    /// The identifier used to register and schedule the background financial data refresh.
    static let backgroundRefreshTaskID = "SpiroProductions.BoxOfficer.refresh"

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BoxOfficerApp.backgroundRefreshTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundRefresh(task: refreshTask)
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh before doing work
        scheduleBackgroundRefresh()

        let context = sharedModelContainer.mainContext
        let taskOperation = Task {
            do {
                let descriptor = FetchDescriptor<Film>(
                    predicate: #Predicate<Film> { $0.isInWatchlist == true }
                )
                let watchlistFilms = try context.fetch(descriptor)
                await NotificationCheckService.shared.checkForUpdates(films: watchlistFilms, context: context)
            } catch {
                print("Background refresh error: \(error)")
            }
        }

        task.expirationHandler = {
            taskOperation.cancel()
        }

        Task {
            await taskOperation.value
            task.setTaskCompleted(success: true)
        }
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshTaskID)

        // Determine interval from user preference
        let frequency = UserDefaults.standard.string(forKey: "updateFrequency") ?? "Daily"
        switch frequency {
        case "Hourly":
            request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        case "Weekly":
            request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60)
        default: // Daily
            request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }

    private func scheduleBackgroundRefresh() {
        BoxOfficerApp.scheduleBackgroundRefresh()
    }
}
