//
//  NotificationCheckService.swift
//  BoxOfficer
//
//  Shared service used by both the foreground NotificationsView and the
//  background BGAppRefreshTask so that notification-check logic lives in
//  one place and always respects the user's notification preference toggles.
//

import Foundation
import SwiftData
import UserNotifications

final class NotificationCheckService {
    static let shared = NotificationCheckService()
    private init() {}

    // MARK: - Public API

    /// Check all watchlist films for financial data changes and emit local
    /// notifications for any changes that match the user's enabled toggles.
    /// Returns the new `BoxOfficeNotification` items that were generated.
    @discardableResult
    func checkForUpdates(films: [Film], context: ModelContext) async -> [BoxOfficeNotification] {
        guard !films.isEmpty else { return [] }

        // Read user preferences once up front
        let enableFinancial   = UserDefaults.standard.bool(forKey: "enableFinancialUpdates",   default: true)
        let enableBudget      = UserDefaults.standard.bool(forKey: "enableBudgetChanges",       default: true)
        let enableBoxOffice   = UserDefaults.standard.bool(forKey: "enableBoxOfficeChanges",    default: true)
        let enableDomestic    = UserDefaults.standard.bool(forKey: "enableDomesticChanges",     default: false)
        let enableInternational = UserDefaults.standard.bool(forKey: "enableInternationalChanges", default: false)

        // If the master switch is off, skip everything
        guard enableFinancial else { return [] }

        var newNotifications: [BoxOfficeNotification] = []

        for film in films {
            do {
                guard let latestData = try await fetchLatestFinancialData(for: film) else { continue }

                let changes = detectFinancialChanges(
                    original: film,
                    updated: latestData,
                    enableBudget: enableBudget,
                    enableBoxOffice: enableBoxOffice,
                    enableDomestic: enableDomestic,
                    enableInternational: enableInternational
                )

                for change in changes {
                    let notification = createNotification(for: change, film: film)
                    newNotifications.append(notification)
                    scheduleLocalNotification(notification)
                }

                // Persist updated financial data
                await MainActor.run {
                    updateFilmData(film, with: latestData, context: context)
                }

            } catch {
                print("NotificationCheckService: error fetching data for \(film.title): \(error)")
            }
        }

        // Persist the new in-app notifications
        if !newNotifications.isEmpty {
            appendStoredNotifications(newNotifications)
        }

        return newNotifications
    }

    // MARK: - Stored Notifications (UserDefaults)

    func loadStoredNotifications() -> [BoxOfficeNotification] {
        guard let data = UserDefaults.standard.data(forKey: "StoredNotifications"),
              let decoded = try? JSONDecoder().decode([BoxOfficeNotification].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.timestamp > $1.timestamp }
    }

    func saveNotifications(_ notifications: [BoxOfficeNotification]) {
        if let encoded = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(encoded, forKey: "StoredNotifications")
        }
    }

    private func appendStoredNotifications(_ new: [BoxOfficeNotification]) {
        var existing = loadStoredNotifications()
        existing.insert(contentsOf: new, at: 0)
        saveNotifications(existing)
    }

    // MARK: - Private Helpers

    private func fetchLatestFinancialData(for film: Film) async throws -> FinancialData? {
        guard let tmdbID = film.tmdbID ?? Int(film.id) else { return nil }
        let details = try await TMDBService.shared.fetchMovieDetails(id: tmdbID)
        return FinancialData(
            budget: details.budget > 0 ? Int64(details.budget) : nil,
            boxOffice: details.revenue > 0 ? Int64(details.revenue) : nil,
            domesticBoxOffice: nil,
            internationalBoxOffice: nil
        )
    }

    private func detectFinancialChanges(
        original: Film,
        updated: FinancialData,
        enableBudget: Bool,
        enableBoxOffice: Bool,
        enableDomestic: Bool,
        enableInternational: Bool
    ) -> [FinancialChange] {
        var changes: [FinancialChange] = []

        if enableBudget,
           let originalBudget = original.budget,
           let updatedBudget = updated.budget,
           originalBudget != updatedBudget {
            changes.append(.budget(from: originalBudget, to: updatedBudget))
        }

        if enableBoxOffice,
           let originalBO = original.boxOffice,
           let updatedBO = updated.boxOffice,
           originalBO != updatedBO {
            changes.append(.boxOffice(from: originalBO, to: updatedBO))
        }

        if enableDomestic,
           let originalDom = original.domesticBoxOffice,
           let updatedDom = updated.domesticBoxOffice,
           originalDom != updatedDom {
            changes.append(.domesticBoxOffice(from: originalDom, to: updatedDom))
        }

        if enableInternational,
           let originalInt = original.internationalBoxOffice,
           let updatedInt = updated.internationalBoxOffice,
           originalInt != updatedInt {
            changes.append(.internationalBoxOffice(from: originalInt, to: updatedInt))
        }

        return changes
    }

    private func createNotification(for change: FinancialChange, film: Film) -> BoxOfficeNotification {
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

    private func scheduleLocalNotification(_ notification: BoxOfficeNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    @MainActor
    private func updateFilmData(_ film: Film, with data: FinancialData, context: ModelContext) {
        if let budget = data.budget { film.budget = budget }
        if let boxOffice = data.boxOffice { film.boxOffice = boxOffice }
        if let domestic = data.domesticBoxOffice { film.domesticBoxOffice = domestic }
        if let international = data.internationalBoxOffice { film.internationalBoxOffice = international }
        try? context.save()
    }
}

// MARK: - UserDefaults Helper

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil { return defaultValue }
        return bool(forKey: key)
    }
}
