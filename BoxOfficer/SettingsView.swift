//
//  SettingsView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData
import StoreKit

@available(iOS 17.0, *)
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var films: [Film]
    @State private var showingDeleteAlert = false
    @State private var showingExportSheet = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // Data Management
                Section("Data Management") {
                    Button(action: {
                        showingExportSheet = true
                    }) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Clear All Data", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }
                

                
                // Display Settings
                Section("Display") {
                    NavigationLink(destination: CurrencySettingsView()) {
                        Label("Currency Format", systemImage: "dollarsign.circle")
                    }
                    
                    NavigationLink(destination: ChartSettingsView()) {
                        Label("Chart Preferences", systemImage: "chart.bar")
                    }
                }
                
                // Notifications
                Section("Notifications") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Notification Settings", systemImage: "bell")
                    }
                }
                
                // App Information
                Section("App Information") {
                    Button(action: {
                        showingAbout = true
                    }) {
                        Label("About Box Officer", systemImage: "info.circle")
                    }
                    
                    HStack {
                        Label("Version", systemImage: "gear")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Support
                Section("Support") {
                    Button(action: {
                        let subject = "BoxOfficer Feedback"
                        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
                        if let url = URL(string: "mailto:support@homielabz.com?subject=\(encodedSubject)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    
                    Button(action: {
                        if let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                    }) {
                        Label("Rate Box Officer", systemImage: "star")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .alert("Delete All Films", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllFilms()
            }
        } message: {
            Text("This will permanently delete all film data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingExportSheet) {
            if #available(iOS 17, *) {
                ExportDataView(films: films)
            } else {
                // Fallback on earlier versions
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    private func deleteAllFilms() {
        withAnimation {
            for film in films {
                modelContext.delete(film)
            }
        }
    }
}



struct CurrencySettingsView: View {
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("showFullNumbers") private var showFullNumbers = false
    
    var body: some View {
        Form {
            Section("Currency") {
                Picker("Currency", selection: $selectedCurrency) {
                    Text("US Dollar (USD)").tag("USD")
                    Text("Euro (EUR)").tag("EUR")
                    Text("British Pound (GBP)").tag("GBP")
                    Text("Japanese Yen (JPY)").tag("JPY")
                }
            }
            
            Section("Number Format") {
                Toggle("Show Full Numbers", isOn: $showFullNumbers)
                
                Text("When disabled, large numbers will be abbreviated (e.g., $1.2B instead of $1,200,000,000)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Currency Format")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChartSettingsView: View {
    @AppStorage("defaultChartType") private var defaultChartType = "Bar"
    @AppStorage("animateCharts") private var animateCharts = true
    @AppStorage("showDataLabels") private var showDataLabels = true
    
    var body: some View {
        Form {
            Section("Chart Type") {
                Picker("Default Chart Type", selection: $defaultChartType) {
                    Text("Bar Chart").tag("Bar")
                    Text("Line Chart").tag("Line")
                    Text("Pie Chart").tag("Pie")
                }
            }
            
            Section("Chart Behavior") {
                Toggle("Animate Charts", isOn: $animateCharts)
                Toggle("Show Data Labels", isOn: $showDataLabels)
            }
        }
        .navigationTitle("Chart Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17, *)
struct ExportDataView: View {
    let films: [Film]
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: URL?
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Export Film Data")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Export your film collection data as a CSV file for use in other applications.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Export will include:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Film titles and details")
                        Text("• Budget and box office data")
                        Text("• Financial analysis")
                        Text("• Watchlist status")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if let error = exportError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: exportCSV) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Export \(films.count) Films")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting || films.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $shareItem) { url in
                ShareSheet(url: url)
            }
        }
    }

    private func exportCSV() {
        isExporting = true
        exportError = nil

        Task {
            do {
                let url = try buildCSV()
                await MainActor.run {
                    shareItem = url
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }

    private func buildCSV() throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let header = "Title,Release Date,Director,Genre,Runtime (min),Budget,Box Office,Domestic Box Office,International Box Office,Profit,Profit Margin (%),Critics Score,Audience Score,IMDb Rating,In Watchlist"

        let rows: [String] = films.map { film in
            let releaseDate = film.releaseDate.map { dateFormatter.string(from: $0) } ?? ""
            let budget = film.budget.map { String($0) } ?? ""
            let boxOffice = film.boxOffice.map { String($0) } ?? ""
            let domestic = film.domesticBoxOffice.map { String($0) } ?? ""
            let international = film.internationalBoxOffice.map { String($0) } ?? ""
            let profit = film.profit.map { String($0) } ?? ""
            let margin = film.profitMargin.map { String(format: "%.1f", $0) } ?? ""
            let critics = film.criticsScore.map { String($0) } ?? ""
            let audience = film.audienceScore.map { String($0) } ?? ""
            let imdb = film.imdbRating.map { String(format: "%.1f", $0) } ?? ""

            // Escape fields that may contain commas or quotes
            let fields: [String] = [
                film.title, releaseDate, film.director, film.genre,
                film.runtime.map { String($0) } ?? "",
                budget, boxOffice, domestic, international,
                profit, margin, critics, audience, imdb,
                film.isInWatchlist ? "Yes" : "No"
            ]
            return fields.map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n")
                    ? "\"\(escaped)\"" : escaped
            }.joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        let data = Data(csv.utf8)

        let fileName = "BoxOfficer-Export-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// A simple `UIActivityViewController` wrapper for sharing a file URL.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "film.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Box Officer")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Box Officer")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Box Officer is your comprehensive tool for analyzing film budgets and box office performance. Track your favorite movies, compare financial metrics, and discover insights about the film industry.")
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "chart.bar.fill", title: "Financial Analysis", description: "Track budgets, box office earnings, and profitability")
                            FeatureRow(icon: "eye.fill", title: "Film Comparison", description: "Compare multiple films side by side")
                            FeatureRow(icon: "bookmark.fill", title: "Watchlist", description: "Save films for later analysis")
                            FeatureRow(icon: "bell.fill", title: "Notifications", description: "Stay updated on box office milestones")
                        }
                    }
                    .padding(.horizontal)
                    
                    Text("Made with ❤️ for film enthusiasts")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("About")
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        SettingsView()
            .modelContainer(for: Film.self, inMemory: true)
    } else {
        // Fallback on earlier versions
    }
}

