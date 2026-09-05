import Foundation
import SwiftData

/// SwiftData-backed OutletLocalCache
actor SwiftDataOutletCache: OutletLocalCache {
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
            let descriptor = FetchDescriptor<CachedOutlet>(predicate: #Predicate { $0.id == outlet.id })
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
actor SwiftDataFoodCache: FoodLocalCache {
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
            let descriptor = FetchDescriptor<CachedFoodItem>(predicate: #Predicate { $0.id == item.id })
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
