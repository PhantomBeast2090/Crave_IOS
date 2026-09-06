import SwiftUI
import SwiftData

@main
struct CraveApp: App {
    let modelContainer: ModelContainer
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager.shared

    init() {
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        do {
            modelContainer = try ModelContainer(
                for: CachedOutlet.self, CachedFoodItem.self, CartItemEntity.self,
                    OrderEntity.self, OrderItemEntity.self,
                configurations: ModelConfiguration(schema: Schema([
                    CachedOutlet.self, CachedFoodItem.self, CartItemEntity.self,
                    OrderEntity.self, OrderItemEntity.self
                ]))
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(modelContainer)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    Task { @MainActor in
                        appState.setRepository(DefaultAppRepository.makeWithSwiftData(modelContainer: modelContainer))
                    }
                }
        }
    }
}
