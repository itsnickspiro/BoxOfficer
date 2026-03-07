//
//  CompareTabView.swift
//  BoxOfficer
//
//  Standalone tab wrapper around CompareFilmsView.
//  Lets the user pick a starting film from their watchlist/collection,
//  then hands off to the existing comparison flow.
//

import SwiftUI
import SwiftData

struct CompareTabView: View {
    @Query(sort: \Film.title) private var films: [Film]
    @State private var selectedFilm: Film?

    var body: some View {
        NavigationView {
            if let film = selectedFilm {
                // Reuse existing comparison UI; reset selection when done
                CompareFilmsView(selectedFilm: film)
                    .navigationBarHidden(true)
                    .onDisappear { selectedFilm = nil }
            } else {
                filmPickerView
            }
        }
    }

    private var filmPickerView: some View {
        Group {
            if films.isEmpty {
                ContentUnavailableView(
                    "No Films Yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Add films from the Home tab to start comparing.")
                )
            } else {
                List(films) { film in
                    Button {
                        selectedFilm = film
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: film.posterURL ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(Image(systemName: "film.fill").foregroundColor(.gray))
                            }
                            .frame(width: 40, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(film.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if !film.director.isEmpty {
                                    Text(film.director)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Compare Films")
    }
}

#Preview {
    CompareTabView()
        .modelContainer(for: Film.self, inMemory: true)
}
