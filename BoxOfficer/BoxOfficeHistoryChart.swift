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
    let releaseDate: Date?
    
    // Computes simulated weekly data points
    private var dataPoints: [WeeklyDataPoint] {
        generateSimulatedRun()
    }
    
    struct WeeklyDataPoint: Identifiable {
        let id = UUID()
        let week: Int
        let cumulativeRevenue: Int64
        let isProfitable: Bool
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if totalBoxOffice > 0 {
                Chart {
                    // Budget Line (Break-even threshold)
                    if budget > 0 {
                        RuleMark(y: .value("Budget", budget))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .foregroundStyle(.gray)
                            .annotation(position: .top, alignment: .leading) {
                                Text("Budget: \(budget.formatted(.currency(code: "USD").scale(1e-6)))M")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    
                    // Revenue Line
                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value("Week", point.week),
                            y: .value("Revenue", point.cumulativeRevenue)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(point.cumulativeRevenue >= budget ? Color.green : Color.red)
                        
                        // Area under the line for better visualization
                        AreaMark(
                            x: .value("Week", point.week),
                            y: .value("Revenue", point.cumulativeRevenue)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    (point.cumulativeRevenue >= budget ? Color.green : Color.red).opacity(0.3),
                                    (point.cumulativeRevenue >= budget ? Color.green : Color.red).opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        // Format large numbers (millions/billions)
                        if let amount = value.as(Int64.self) {
                            AxisValueLabel {
                                Text(formatCompactCurrency(amount))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        if let week = value.as(Int.self) {
                            AxisValueLabel {
                                Text("W\(week)")
                            }
                        }
                    }
                }
                .frame(height: 250)
                
                // Legend / Explanation
                HStack(spacing: 16) {
                    Label("Budget threshold", systemImage: "line.dash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Label("Cumulative Revenue", systemImage: "chart.xyaxis.line")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                
            } else {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line", description: Text("Box office data is not available for this film."))
                } else {
                    // Fallback on earlier versions
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // Helper to format currency axis labels
    private func formatCompactCurrency(_ amount: Int64) -> String {
        if amount >= 1_000_000_000 {
            return String(format: "$%.1fB", Double(amount) / 1_000_000_000)
        } else if amount >= 1_000_000 {
            return String(format: "$%.0fM", Double(amount) / 1_000_000)
        } else {
            return amount.formatted(.currency(code: "USD"))
        }
    }
    
    // Simulate a theatrical run
    private func generateSimulatedRun() -> [WeeklyDataPoint] {
        guard totalBoxOffice > 0 else { return [] }
        
        var points: [WeeklyDataPoint] = []
        let weeks = 12
        var currentTotal: Double = 0
        let targetTotal = Double(totalBoxOffice)
        
        // Standard decay curve simulation
        // Week 1 is highest, then decays
        // We'll use a simple series that sums to ~1.0 and scale it
        
        // Weights for 12 weeks (approximate decay)
        let weights = [0.35, 0.20, 0.12, 0.08, 0.06, 0.05, 0.04, 0.03, 0.025, 0.02, 0.015, 0.01]
        
        for i in 0..<weeks {
            let weight = i < weights.count ? weights[i] : 0.0
            let weeklyRevenue = targetTotal * weight
            currentTotal += weeklyRevenue
            
            // Adjust last point to exactly match total if needed, or just let it be close
            // For this sim, we'll cap it at targetTotal for the last one
            if i == weeks - 1 {
                currentTotal = targetTotal
            }
            
            let revenueInt = Int64(currentTotal)
            points.append(WeeklyDataPoint(
                week: i + 1,
                cumulativeRevenue: revenueInt,
                isProfitable: budget > 0 && revenueInt >= budget
            ))
        }
        
        return points
    }
}
