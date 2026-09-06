import Foundation

// MARK: - Outlet Repository Protocol

protocol OutletRepository: Sendable {
    /// Observe cached outlets (for offline-first UI)
    func observeOutlets() -> AsyncStream<[Outlet]>
    
    /// Refresh outlets from Supabase (student-facing: is_active = true)
    func refreshOutlets() async throws -> [Outlet]

    /// Refresh ALL outlets including inactive (admin management).
    func refreshAllOutlets() async throws -> [Outlet]
    
    /// Get a single outlet by ID (checks cache first, then network)
    func getOutletById(_ outletId: String) async throws -> Outlet
    
    /// Get nearby outlets (currently fetches all active - PostGIS not yet implemented)
    func getNearbyOutlets(lat: Double, lng: Double) async throws -> [Outlet]
}

// MARK: - Food Repository Protocol

protocol FoodRepository: Sendable {
    // MARK: - Read Operations
    
    /// Search food using the secure `search_food` RPC
    func searchFood(filter: FoodSearchFilter) async throws -> [FoodItem]
    
    /// Get food item by ID with full variants (bypasses cache for live data)
    func getFoodById(_ foodId: String) async throws -> FoodItem
    
    /// Get menu for a specific outlet
    func getMenuByOutlet(_ outletId: String) async throws -> [FoodItem]
    
    /// Get popular food items
    func getPopularFood() async throws -> [FoodItem]
    
    /// Get recommended food items
    func getRecommendedFood() async throws -> [FoodItem]
    
    /// Get all available food items
    func getAllFood() async throws -> [FoodItem]
    
    /// Get all categories
    func getCategories() async throws -> [FoodCategory]
    
    // MARK: - Favorites
    
    /// Observe user's favorites
    func observeFavorites() -> AsyncStream<[FoodItem]>
    
    /// Sync favorites from Supabase to local cache
    func syncFavorites() async throws -> [FoodItem]
    
    /// Toggle favorite status (local + Supabase)
    func toggleFavorite(foodItemId: String) async throws -> Bool
    
    /// Check if item is favorited
    func isFavorite(foodItemId: String) async throws -> Bool
    
    // MARK: - Vendor Operations
    
    /// Get vendor's food items (for vendor dashboard)
    func getVendorFoodItems() async throws -> [FoodItem]
    
    /// Update food availability
    func updateFoodAvailability(foodId: String, isAvailable: Bool) async throws
    
    /// Update food price
    func updateFoodPrice(foodId: String, price: Double) async throws
}

// MARK: - Combined Repository (for DI convenience)

protocol AppRepository: Sendable {
    var outlets: OutletRepository { get }
    var food: FoodRepository { get }
    var cart: CartRepository { get }
    var orders: OrderRepository { get }
    var notifications: NotificationRepository { get }
    var payments: PaymentRepository { get }
    var admin: AdminRepository { get }
}
