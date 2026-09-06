import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var favorites: [FoodItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var quickAdd: QuickAddHelper?

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
                        if let addError = quickAdd?.errorMessage {
                            Text(addError)
                                .font(GagTypography.labelMedium)
                                .foregroundStyle(GagColors.error)
                        }
                        ForEach(favorites) { item in
                            NavigationLink {
                                FoodDetailView(foodId: item.id, outletId: item.outletId)
                            } label: {
                                FoodItemCard(item: item, onAddToCart: { quickAdd?.quickAdd(item) })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(GagShapes.spacingL)
                }
            }
        }
        .navigationTitle("Favorites")
        .task {
            if quickAdd == nil {
                quickAdd = QuickAddHelper(repository: appState.repository.cart)
            }
            await loadFavorites()
        }
        .refreshable { await loadFavorites() }
        .navigationDestination(item: detailBinding) { item in
            FoodDetailView(foodId: item.id, outletId: item.outletId)
        }
        .alert("Different Outlet", isPresented: conflictBinding) {
            Button("Clear & Add", role: .destructive) {
                quickAdd?.confirmConflictAdd()
            }
            Button("Keep Cart", role: .cancel) {
                quickAdd?.dismissConflict()
            }
        } message: {
            Text("Your cart contains items from a different outlet. Clear cart and add from this outlet?")
        }
        .overlay(alignment: .bottom) {
            if let message = quickAdd?.toastMessage {
                GagToast(message: message)
                    .padding(.bottom, 90)
            }
        }
    }

    private var detailBinding: Binding<FoodItem?> {
        Binding(
            get: { quickAdd?.detailItem },
            set: { quickAdd?.detailItem = $0 }
        )
    }

    private var conflictBinding: Binding<Bool> {
        Binding(
            get: { quickAdd?.conflictItem != nil },
            set: { if !$0 { quickAdd?.dismissConflict() } }
        )
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
