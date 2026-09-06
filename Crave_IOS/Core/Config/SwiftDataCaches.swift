import Foundation
import SwiftData

/// SwiftData-backed OutletLocalCache
@MainActor
final class SwiftDataOutletCache: OutletLocalCache {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func observeOutlets() -> AsyncStream<[Outlet]> {
        AsyncStream { continuation in
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<CachedOutlet>(sortBy: [SortDescriptor(\.name)])
            
            // Initial load
            do {
                let cached = try context.fetch(descriptor)
                continuation.yield(cached.map { $0.toOutlet() })
            } catch {
                continuation.yield([])
            }
            
            // Note: For real-time observation, you'd use SwiftData's observation APIs
            // For now, we'll just provide initial data
            
            continuation.onTermination = { @Sendable _ in }
        }
    }
    
    func getOutletById(_ id: String) async -> Outlet? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedOutlet>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first?.toOutlet()
    }
    
    func saveOutlet(_ outlet: Outlet) async throws {
        let context = ModelContext(modelContainer)
        let cached = CachedOutlet(outlet: outlet)
        context.insert(cached)
        try context.save()
    }
    
    func saveOutlets(_ outlets: [Outlet]) async throws {
        let context = ModelContext(modelContainer)
        for outlet in outlets {
            let outletId = outlet.id
            let descriptor = FetchDescriptor<CachedOutlet>(predicate: #Predicate { $0.id == outletId })
            if let existing = try context.fetch(descriptor).first {
                // Update existing
                let updated = CachedOutlet(outlet: outlet)
                context.delete(existing)
                context.insert(updated)
            } else {
                context.insert(CachedOutlet(outlet: outlet))
            }
        }
        try context.save()
    }
}

/// SwiftData-backed FoodLocalCache
@MainActor
final class SwiftDataFoodCache: FoodLocalCache {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func observeFavorites() -> AsyncStream<[FoodItem]> {
        AsyncStream { continuation in
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<CachedFoodItem>(
                predicate: #Predicate { $0.isFavorite == true }
            )
            
            do {
                let cached = try context.fetch(descriptor)
                continuation.yield(cached.map { $0.toFoodItem() })
            } catch {
                continuation.yield([])
            }
            
            continuation.onTermination = { @Sendable _ in }
        }
    }
    
    func saveFoodItems(_ items: [FoodItem]) async throws {
        let context = ModelContext(modelContainer)
        for item in items {
            let itemId = item.id
            let descriptor = FetchDescriptor<CachedFoodItem>(predicate: #Predicate { $0.id == itemId })
            if let existing = try context.fetch(descriptor).first {
                let updated = CachedFoodItem(foodItem: item)
                updated.isFavorite = existing.isFavorite // Preserve favorite status
                context.delete(existing)
                context.insert(updated)
            } else {
                context.insert(CachedFoodItem(foodItem: item))
            }
        }
        try context.save()
    }
    
    func isFavorite(_ foodItemId: String) async throws -> Bool {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedFoodItem>(predicate: #Predicate { $0.id == foodItemId })
        return try context.fetch(descriptor).first?.isFavorite ?? false
    }
    
    func updateFavorite(_ foodItemId: String, isFavorite: Bool) async throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedFoodItem>(predicate: #Predicate { $0.id == foodItemId })
        if let item = try context.fetch(descriptor).first {
            item.isFavorite = isFavorite
            try context.save()
        }
    }
}

/// SwiftData-backed CartLocalStore — the cart survives app restarts.
@MainActor
final class SwiftDataCartStore: CartLocalStore {
    private let modelContainer: ModelContainer
    private var continuations: [UUID: AsyncStream<[CartItemEntity]>.Continuation] = [:]

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func loadAll() async -> [CartItemEntity] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CartItemEntity>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func upsert(_ item: CartItemEntity) async throws {
        let context = ModelContext(modelContainer)
        let itemId = item.id
        let descriptor = FetchDescriptor<CartItemEntity>(predicate: #Predicate { $0.id == itemId })
        if (try context.fetch(descriptor)).first == nil {
            context.insert(item)
        }
        try context.save()
    }

    func delete(id: String) async throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CartItemEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    func clear() async throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CartItemEntity>()
        for existing in (try? context.fetch(descriptor)) ?? [] {
            context.delete(existing)
        }
        try context.save()
    }

    func observe() -> AsyncStream<[CartItemEntity]> {
        let id = UUID()
        return AsyncStream { continuation in
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
