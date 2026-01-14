//
//  SettingsView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData

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
                        // Open feedback form
                    }) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    
                    Button(action: {
                        // Rate app
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
                
                Button("Export \(films.count) Films") {
                    // Export functionality would go here
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
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
        }
    }
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

