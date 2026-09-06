import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var favorites: [FoodItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                GagLoadingView(message: "Loading favorites…")
            } else if let errorMessage {
                GagErrorView(message: errorMessage) {
                    Task { await loadFavorites() }
                }
                .padding(.horizontal, GagShapes.spacingL)
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
        isLoading = favorites.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            favorites = try await appState.repository.food.syncFavorites()
        } catch is CancellationError {
        } catch {
            if favorites.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
