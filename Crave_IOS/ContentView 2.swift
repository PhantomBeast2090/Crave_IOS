// ContentView.swift
// Canonical ContentView
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: SessionManager

    var body: some View {
        Group {
            switch session.authState {
            case .unknown:
                ProgressView("Loading…")
            case .unauthenticated:
                LoginView()
            case .authenticated:
                MainView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionManager())
}

// NOTE: Ensure no other file declares struct ContentView or @main App.
