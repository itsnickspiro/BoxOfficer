//
//  PostTheatricalChart.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 1/17/26.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct PostTheatricalChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Post-Theatrical Performance")
                .font(.headline)
                .padding(.leading, 4)
            
            // Placeholder Chart Container
            ZStack {
                Chart {
                    // Empty chart to maintain axis layout consistency if desired,
                    // or just a placeholder visual.
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.clear)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                    }
                }
                .frame(height: 250)
                
                if #available(iOS 17.0, *) {
                    ContentUnavailableView("Data Unavailable", systemImage: "tv", description: Text("Digital & Physical sales data is not currently available."))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "tv")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Data Unavailable")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Digital & Physical sales data is not currently available.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
