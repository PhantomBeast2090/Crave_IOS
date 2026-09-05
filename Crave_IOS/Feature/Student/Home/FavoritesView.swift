import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var favorites: [FoodItem] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                GagLoadingView(message: "Loading favorites…")
            } else if favorites.isEmpty {
                GagEmptyView(
                    icon: "heart",
                    title: "No favorites yet",
                    message: "Tap the heart on any food item to save it here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: GagShapes.spacingM) {
                        ForEach(favorites) { item in
                            NavigationLink {
                                FoodDetailView(foodId: item.id, outletId: item.outletId)
                            } label: {
                                FoodItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(GagShapes.spacingL)
                }
            }
        }
        .navigationTitle("Favourites")
        .task {
            await loadFavorites()
        }
        .refreshable { await loadFavorites() }
    }
    
    private func loadFavorites() async {
        isLoading = true
        do {
            favorites = try await appState.repository.food.syncFavorites()
            // The syncFavorites returns items, but observeFavorites is better for real-time
            // For now, just load once
        } catch {
            print("Failed to load favorites: \(error)")
        }
        isLoading = false
    }
}
