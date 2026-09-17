import SwiftUI
import SwiftData

@main
struct CraveApp: App {
    // The composition root owns persistence (AppState creates the container
    // eagerly: same store for every capture, degraded in-memory fallback
    // instead of a launch crash).
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(appState.modelContainer)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
