import SwiftUI

@main
struct CraveApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(GagColors.brandOrange)
        }
    }
}
