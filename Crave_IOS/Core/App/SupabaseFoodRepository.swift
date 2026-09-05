import Foundation
import Supabase

/// Supabase-backed FoodRepository implementation.
/// Mirrors Android's SupabaseFoodRepository exactly.
final class SupabaseFoodRepository: FoodRepository, Sendable {
    private let client: SupabaseClient
    private let auth: AuthClient
    private let localCache: FoodLocalCache
    
    // Column selection string matching Android exactly
    private let foodColumns = "*, outlets(name), categories(name, emoji, image_url), food_variants(*, food_variant_options(*))"
    
    init(client: SupabaseClient, auth: AuthClient, localCache: FoodLocalCache) {
        self.client = client
        self.auth = auth
        self.localCache = localCache
    }
    
    // MARK: - Read Operations
    
    func searchFood(filter: FoodSearchFilter) async throws -> [FoodItem] {
        print("🔍 [SupabaseFoodRepo] Searching food with query='\(filter.query)'")
        
        let params = SearchFoodParams(
            pQuery: filter.query,
            pOutletId: filter.outletId,
            pCategory: filter.category,
            pIsVeg: filter.isVeg,
            pMaxPrice: filter.maxPrice,
            pAvailableOnly: filter.availableOnly
        )
        
        let dtos: [FoodItemDto] = try await client
            .rpc("search_food", params: params)
            .execute()
            .value
        
        print("✅ [SupabaseFoodRepo] Retrieved \(dtos.count) food items from RPC")
        
        let favIds = try await getFavoriteIds()
        let domains = dtos.map { $0.toDomain(favoriteIds: favIds) }
        
        // Client-side sort for options not handled by RPC
        return sortFoodItems(domains, by: filter.sortBy)
    }
    
    func getFoodById(_ foodId: String) async throws -> FoodItem {
        print("🌐 [SupabaseFoodRepo] Fetching food \(foodId) with full variants...")
        
        let dto: FoodItemDto = try await client
            .from("food_items")
            .select(foodColumns)
            .eq("id", value: foodId)
            .single()
            .execute()
            .value
        
        let favIds = try await getFavoriteIds()
        return dto.toDomain(favoriteIds: favIds)
    }
    
    func getMenuByOutlet(_ outletId: String) async throws -> [FoodItem] {
        print("🍽️ [SupabaseFoodRepo] Fetching menu for outlet \(outletId)...")
        
        let dtos: [FoodItemDto] = try await client
            .from("food_items")
            .select(foodColumns)
            .eq("outlet_id", value: outletId)
            .execute()
            .value
        
        print("✅ [SupabaseFoodRepo] Retrieved \(dtos.count) food items")
        
        let favIds = try await getFavoriteIds()
        let domains = dtos.map { $0.toDomain(favoriteIds: favIds) }
        
        try await localCache.saveFoodItems(domains)
        
        return domains
    }
    
    func getPopularFood() async throws -> [FoodItem] {
        let dtos: [FoodItemDto] = try await client
            .from("food_items")
            .select(foodColumns)
            .eq("is_popular", value: true)
            .eq("is_available", value: true)
            .execute()
            .value
        
        let favIds = try await getFavoriteIds()
        return dtos.map { $0.toDomain(favoriteIds: favIds) }
    }
    
    func getRecommendedFood() async throws -> [FoodItem] {
        let dtos: [FoodItemDto] = try await client
            .from("food_items")
            .select(foodColumns)
            .eq("is_recommended", value: true)
            .eq("is_available", value: true)
            .execute()
            .value
        
        let favIds = try await getFavoriteIds()
        return dtos.map { $0.toDomain(favoriteIds: favIds) }
    }
    
    func getAllFood() async throws -> [FoodItem] {
        print("📋 [SupabaseFoodRepo] Fetching all available food items...")
        
        let dtos: [FoodItemDto] = try await client
            .from("food_items")
            .select(foodColumns)
            .eq("is_available", value: true)
            .execute()
            .value
        
        print("✅ [SupabaseFoodRepo] Retrieved \(dtos.count) items")
        
        let favIds = try await getFavoriteIds()
        return dtos.map { $0.toDomain(favoriteIds: favIds) }
    }
    
    func getCategories() async throws -> [FoodCategory] {
        let dtos: [CategoryDto] = try await client
            .from("categories")
            .select()
            .execute()
            .value
        
        return dtos.map { dto in
            FoodCategory(
                id: dto.id,
                name: dto.name,
                emoji: dto.emoji,
                imageUrl: dto.imageUrl
            )
        }
    }
    
    // MARK: - Favorites
    
    func observeFavorites() -> AsyncStream<[FoodItem]> {
        localCache.observeFavorites()
    }
    
    func syncFavorites() async throws {
        let favIds = try await getFavoriteIds()
        guard !favIds.isEmpty else { return }
        
        let dtos: [FoodItemDto] = try await client
            .from("food_items")
            .select(foodColumns)
            .in("id", values: Array(favIds))
            .execute()
            .value
        
        let domains = dtos.map { $0.toDomain(favoriteIds: favIds) }
        try await localCache.saveFoodItems(domains)
    }
    
    func toggleFavorite(_ foodItemId: String) async throws -> Bool {
        let current = try await localCache.isFavorite(foodItemId)
        let newStatus = !current
        
        try await localCache.updateFavorite(foodItemId, isFavorite: newStatus)
        
        // Sync to Supabase favorites table
        if let userId = auth.currentSession?.user.id.uuidString {
            if newStatus {
                try await client
                    .from("favorites")
                    .upsert(FavoriteInsert(userId: userId, foodItemId: foodItemId))
                    .execute()
            } else {
                try await client
                    .from("favorites")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("food_item_id", value: foodItemId)
                    .execute()
            }
        }
        
        return newStatus
    }
    
    func isFavorite(_ foodItemId: String) async throws -> Bool {
        try await localCache.isFavorite(foodItemId)
    }
    
    // MARK: - Vendor Operations
    
    func getVendorFoodItems() async throws -> [FoodItem] {
        guard let userId = auth.currentSession?.user.id.uuidString else {
            throw AppError.message("Not logged in")
        }
        
        let outletDtos: [OutletIdDto] = try await client
            .from("outlets")
            .select("id")
            .eq("vendor_id", value: userId)
            .execute()
            .value
        
        let outletIds = outletDtos.map { $0.id }
        guard !outletIds.isEmpty else { return [] }
        
        let dtos: [FoodItemDto] = try await client
            .from("food_items")
            .select(foodColumns)
            .in("outlet_id", values: outletIds)
            .execute()
            .value
        
        return dtos.map { $0.toDomain(favoriteIds: []) }
    }
    
    func updateFoodAvailability(_ foodId: String, isAvailable: Bool) async throws {
        try await client
            .from("food_items")
            .update(["is_available": isAvailable])
            .eq("id", value: foodId)
            .execute()
    }
    
    func updateFoodPrice(_ foodId: String, price: Double) async throws {
        try await client
            .from("food_items")
            .update(["price": price])
            .eq("id", value: foodId)
            .execute()
    }
    
    // MARK: - Private Helpers
    
    private func getFavoriteIds() async throws -> Set<String> {
        guard let userId = auth.currentSession?.user.id.uuidString else {
            return []
        }
        
        do {
            let rows: [FavRowDto] = try await client
                .from("favorites")
                .select("food_item_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            return Set(rows.map { $0.foodItemId })
        } catch {
            return []
        }
    }
    
    private func sortFoodItems(_ items: [FoodItem], by sortOption: SortOption) -> [FoodItem] {
        switch sortOption {
        case .priceLowToHigh: return items.sorted { $0.price < $1.price }
        case .priceHighToLow: return items.sorted { $0.price > $1.price }
        case .rating: return items.sorted { $0.rating > $1.rating }
        case .prepTime: return items.sorted { $0.prepTimeMinutes < $1.prepTimeMinutes }
        case .relevance: return items
        }
    }
}

// MARK: - Food DTO → Domain Mapping

extension FoodItemDto {
    func toDomain(favoriteIds: Set<String>) -> FoodItem {
        let isFav = favoriteIds.contains(id)
        
        return FoodItem(
            id: id,
            name: name,
            description: description,
            imageUrl: imageUrl,
            price: price,
            outletId: outletId,
            outletName: outlet?.name ?? "",
            category: category?.name ?? "",
            isVeg: isVeg ?? true,
            isAvailable: isAvailable,
            prepTimeMinutes: prepTimeMinutes,
            rating: rating,
            totalReviews: totalReviews,
            ingredients: ingredients ?? [],
            customizations: (variants ?? []).map { variant in
                FoodCustomization(
                    id: variant.id,
                    name: variant.name,
                    options: (variant.options ?? []).map { opt in
                        CustomizationOption(
                            id: opt.id,
                            name: opt.name,
                            extraPrice: opt.extraPrice
                        )
                    },
                    isRequired: variant.isRequired,
                    maxSelections: variant.maxSelections
                )
            },
            tags: tags ?? [],
            calories: calories,
            isPopular: isPopular,
            isRecommended: isRecommended,
            isFavorite: isFav
        )
    }
}

// MARK: - Local Cache Protocol

protocol FoodLocalCache: Sendable {
    func observeFavorites() -> AsyncStream<[FoodItem]>
    func saveFoodItems(_ items: [FoodItem]) async throws
    func isFavorite(_ foodItemId: String) async throws -> Bool
    func updateFavorite(_ foodItemId: String, isFavorite: Bool) async throws
}
