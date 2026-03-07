//
//  BoxOfficeHistoryChart.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct BoxOfficeHistoryChart: View {
    let budget: Int64
    let totalBoxOffice: Int64
    let domestic: Int64?
    let international: Int64?
    let releaseDate: Date?
    
    // Interactive State
    @State private var selectedWeek: Int?
    @State private var isDragging = false
    @State private var showDomestic = true
    @State private var showInternational = true
    
    // Initializer
    init(budget: Int64, totalBoxOffice: Int64, domestic: Int64? = nil, international: Int64? = nil, releaseDate: Date? = nil) {
        self.budget = budget
        self.totalBoxOffice = totalBoxOffice
        self.domestic = domestic
        self.international = international
        self.releaseDate = releaseDate
    }
    
    // Data
    private var dataPoints: [WeeklyDataPoint] {
        generateSimulatedRun()
    }
    
    struct WeeklyDataPoint: Identifiable {
        let id = UUID()
        let week: Int
        let revenue: Int64
        let source: String
    }
    
    // Helper to get exact values for the selected week
    private func getSelectedData(for week: Int) -> (dom: Int64?, int: Int64?) {
        let dom = dataPoints.first { $0.week == week && $0.source == "Domestic" }?.revenue
        let int = dataPoints.first { $0.week == week && $0.source == "International" }?.revenue
        return (dom, int)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header: Dynamic Value Display (Robinhood style)
            VStack(alignment: .leading, spacing: 4) {
                Text("Theatrical Performance")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if let selected = selectedWeek {
                    let amounts = getSelectedData(for: selected)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Week \(selected)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        
                        Divider().frame(height: 20)
                        
                        if showDomestic, let dom = amounts.dom {
                            Text("Dom: \(formatCompactCurrency(dom))")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        if showInternational, let int = amounts.int {
                            Text("Int: \(formatCompactCurrency(int))")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                        }
                    }
                    .transition(.opacity)
                } else {
                    // Default State
                    Text(formatCompactCurrency(totalBoxOffice))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
            .padding(.leading, 4)
            .frame(height: 40) // Fixed height to prevent jumpiness
            
            if totalBoxOffice > 0 {
                Chart {
                    // Budget Line
                    if budget > 0 {
                        RuleMark(y: .value("Budget", budget))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(.gray)
                    }
                    
                    // Series Lines
                    if showDomestic {
                        ForEach(dataPoints.filter { $0.source == "Domestic" }) { point in
                            LineMark(
                                x: .value("Week", point.week),
                                y: .value("Revenue", point.revenue)
                            )
                            .foregroundStyle(Color.blue)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    
                    if showInternational {
                        ForEach(dataPoints.filter { $0.source == "International" }) { point in
                            LineMark(
                                x: .value("Week", point.week),
                                y: .value("Revenue", point.revenue)
                            )
                            .foregroundStyle(Color.purple)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    
                    // Active Selection Rule
                    if let selected = selectedWeek {
                        RuleMark(x: .value("Week", selected))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .annotation(position: .top) {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 8, height: 8)
                                    .shadow(radius: 2)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        if let amount = value.as(Int64.self) {
                            AxisValueLabel { Text(formatCompactCurrency(amount)) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        if let week = value.as(Int.self) {
                            AxisValueLabel { Text("W\(week)") }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        isDragging = true
                                        let startX = proxy.plotFrame.map { geometry[$0].origin.x } ?? 0
                                        let currentX = value.location.x - startX
                                        
                                        if let week: Int = proxy.value(atX: currentX) {
                                            selectedWeek = min(max(1, week), 20) // Clamp to week range
                                        }
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                        selectedWeek = nil
                                    }
                            )
                    }
                }
                .frame(height: 250)
                
                // Toggles
                HStack(spacing: 24) {
                    Toggle(isOn: $showDomestic) {
                        Label("Domestic", systemImage: "circle.fill")
                            .foregroundColor(.blue)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    
                    Toggle(isOn: $showInternational) {
                        Label("International", systemImage: "circle.fill")
                            .foregroundColor(.purple)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    
                    Spacer()
                }
                .padding(.top, 8)
                
            } else {
                ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line", description: Text("Box office data is not available for this film."))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatCompactCurrency(_ amount: Int64) -> String {
        if amount >= 1_000_000_000 {
            return String(format: "$%.1fB", Double(amount) / 1_000_000_000)
        } else if amount >= 1_000_000 {
            return String(format: "$%.0fM", Double(amount) / 1_000_000)
        } else {
            return amount.formatted(.currency(code: "USD"))
        }
    }
    
    private func generateSimulatedRun() -> [WeeklyDataPoint] {
        guard totalBoxOffice > 0 else { return [] }
        
        var points: [WeeklyDataPoint] = []
        let weeks = 20 // Enhanced granularity
        
        let domTotal = Double(domestic ?? (totalBoxOffice / 2))
        let intTotal = Double(international ?? (totalBoxOffice - Int64(domTotal)))
        
        // Logarithmic decay weights
        for i in 0..<weeks {
            // Simplified smooth curve logic
            let progress = Double(i + 1) / Double(weeks)
            let curve = 1.0 - pow(1.0 - progress, 3.0) // Cubic ease-out
            
            let domVal = Int64(domTotal * curve)
            let intVal = Int64(intTotal * curve)
            
            points.append(WeeklyDataPoint(week: i+1, revenue: domVal, source: "Domestic"))
            points.append(WeeklyDataPoint(week: i+1, revenue: intVal, source: "International"))
        }
        
        return points
    }
}

// Custom Checkbox Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .primary : .secondary)
                configuration.label
                    .font(.subheadline)
            }
        }
        .buttonStyle(.plain)
    }
}
