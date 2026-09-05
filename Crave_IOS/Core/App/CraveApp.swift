import SwiftUI
import SwiftData

@main
struct CraveApp: App {
    let modelContainer: ModelContainer
    @State private var appState = AppState()

    init() {
        do {
            modelContainer = try ModelContainer(
                for: CachedOutlet.self, CachedFoodItem.self, CartItemEntity.self, OrderEntity.self,
                configurations: ModelConfiguration(schema: Schema([
                    CachedOutlet.self, CachedFoodItem.self, CartItemEntity.self, OrderEntity.self
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
                .onAppear {
                    Task { @MainActor in
                        appState.setRepository(DefaultAppRepository.makeWithSwiftData(modelContainer: modelContainer))
                    }
                }
        }
    }
}
