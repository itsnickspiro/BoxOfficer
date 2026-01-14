//
//  ContentView.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import SwiftUI
import SwiftData

@available(iOS 17, *)
struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

@available(iOS 17, *)
#Preview {
    ContentView()
        .modelContainer(for: Film.self, inMemory: true)
}
