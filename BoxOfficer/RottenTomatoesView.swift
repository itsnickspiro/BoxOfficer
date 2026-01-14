//
//  RottenTomatoesView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/27/25.
//

import SwiftUI

@available(iOS 17.0, *)
struct RottenTomatoesView: View {
    let film: Film
    let size: CGFloat
    let showLabels: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Critics Score
            if let criticsScore = film.criticsScore {
                HStack(alignment: .center, spacing: 4) {
                    Image(criticsImageName(for: criticsScore))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                    
                    Text("\(criticsScore)%")
                        .font(.system(size: size - 2))
                        .fontWeight(.medium)
                }
                .conditionalBackground(showLabels: showLabels)
            }
            
            // Audience Score
            if let audienceScore = film.audienceScore {
                HStack(alignment: .center, spacing: 4) {
                    Image(audienceImageName(for: audienceScore))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                    
                    Text("\(audienceScore)%")
                        .font(.system(size: size - 2))
                        .fontWeight(.medium)
                }
                .conditionalBackground(showLabels: showLabels)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func criticsImageName(for score: Int) -> String {
        if score >= 75 {
            return "Certified-Fresh" // Certified Fresh (75%+)
        } else if score >= 60 {
            return "Fresh" // Fresh (60-74%)
        } else {
            return "Rotten" // Rotten (<60%)
        }
    }
    
    private func audienceImageName(for score: Int) -> String {
        if score >= 60 {
            return "Audience-Fresh" // Positive Audience (60%+)
        } else {
            return "Audience-Rotten" // Negative Audience (<60%)
        }
    }
}

// MARK: - View Extensions
@available(iOS 17.0, *)
extension View {
    @ViewBuilder
    func conditionalBackground(showLabels: Bool) -> some View {
        if showLabels {
            self
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(.systemGray6))
                .cornerRadius(6)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        if #available(iOS 17, *) {
            // High scoring film
            RottenTomatoesView(
                film: Film(
                    id: "1",
                    title: "Great Movie",
                    criticsScore: 95,
                    audienceScore: 88
                ),
                size: 16,
                showLabels: true
            )
            
            // Mixed scores
            RottenTomatoesView(
                film: Film(
                    id: "2",
                    title: "Mixed Reviews",
                    criticsScore: 65,
                    audienceScore: 45
                ),
                size: 16,
                showLabels: true
            )
            
            // Low scoring film
            RottenTomatoesView(
                film: Film(
                    id: "3",
                    title: "Bad Movie",
                    criticsScore: 25,
                    audienceScore: 30
                ),
                size: 16,
                showLabels: true
            )
            
            // Compact version without labels
            RottenTomatoesView(
                film: Film(
                    id: "4",
                    title: "Compact View",
                    criticsScore: 78,
                    audienceScore: 82
                ),
                size: 14,
                showLabels: false
            )
        } else {
            Text("iOS 17 required")
        }
    }
    .padding()
}