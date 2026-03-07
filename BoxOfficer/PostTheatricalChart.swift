//
//  PostTheatricalChart.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 1/17/26.
//

import SwiftUI
import Charts


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
                
                ContentUnavailableView("Data Unavailable", systemImage: "tv", description: Text("Digital & Physical sales data is not currently available."))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
