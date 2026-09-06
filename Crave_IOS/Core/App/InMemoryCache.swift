import Foundation
import SwiftData

/// In-memory cache implementation for development/testing.
/// Replace with SwiftData/GRDB/CoreData for production persistence.

@MainActor
final class InMemoryOutletCache: OutletLocalCache {
    private var outlets: [String: Outlet] = [:]
    private var continuations: [UUID: AsyncStream<[Outlet]>.Continuation] = [:]
    
    func observeOutlets() -> AsyncStream<[Outlet]> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(Array(outlets.values))
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.removeContinuation(id)
                }
            }
        }
    }
    
    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
    
    private func notify() {
        let items = Array(outlets.values)
        for continuation in continuations.values {
            continuation.yield(items)
        }
    }
    
    func getOutletById(_ id: String) async -> Outlet? {
        outlets[id]
    }
    
    func saveOutlet(_ outlet: Outlet) async throws {
        outlets[outlet.id] = outlet
        notify()
    }
    
    func saveOutlets(_ outlets: [Outlet]) async throws {
        for outlet in outlets {
            self.outlets[outlet.id] = outlet
        }
        notify()
    }
}

@MainActor
final class InMemoryFoodCache: FoodLocalCache {
    private var foodItems: [String: FoodItem] = [:]
    private var favoriteIds: Set<String> = []
    private var continuations: [UUID: AsyncStream<[FoodItem]>.Continuation] = [:]
    
    func observeFavorites() -> AsyncStream<[FoodItem]> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            let favs = favoriteIds.compactMap { foodItems[$0] }
            continuation.yield(favs)
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.removeContinuation(id)
                }
            }
        }
    }
    
    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
    
    private func notifyFavorites() {
        let favs = favoriteIds.compactMap { foodItems[$0] }
        for continuation in continuations.values {
            continuation.yield(favs)
        }
    }
    
    func saveFoodItems(_ items: [FoodItem]) async throws {
        for item in items {
            foodItems[item.id] = item
        }
    }
    
    func isFavorite(_ foodItemId: String) async throws -> Bool {
        favoriteIds.contains(foodItemId)
    }
    
    func updateFavorite(_ foodItemId: String, isFavorite: Bool) async throws {
        if isFavorite {
            favoriteIds.insert(foodItemId)
        } else {
            favoriteIds.remove(foodItemId)
        }
        notifyFavorites()
    }
}

@MainActor
final class InMemoryCartStore: CartLocalStore {
    private var items: [String: CartItemEntity] = [:]
    private var continuations: [UUID: AsyncStream<[CartItemEntity]>.Continuation] = [:]

    func loadAll() async -> [CartItemEntity] {
        items.values.sorted { $0.createdAt < $1.createdAt }
    }

    func upsert(_ item: CartItemEntity) async throws {
        items[item.id] = item
    }

    func delete(id: String) async throws {
        items.removeValue(forKey: id)
    }

    func clear() async throws {
        items.removeAll()
    }

    func observe() -> AsyncStream<[CartItemEntity]> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            Task { @MainActor in
                continuation.yield(await self.loadAll())
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    func notifyChanged() async {
        let items = await loadAll()
        for continuation in continuations.values {
            continuation.yield(items)
        }
    }
}
