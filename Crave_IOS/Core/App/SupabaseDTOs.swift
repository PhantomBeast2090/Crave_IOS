import Foundation

// MARK: - Outlet DTOs (matching actual Supabase schema)

nonisolated struct OutletDto: Decodable, Sendable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String?
    let vendorId: String?
    let isOpen: Bool
    let isActive: Bool
    let phone: String?
    let building: String?
    let floor: String?
    let locationDescription: String?
    let latitude: Double?
    let longitude: Double?
    let operatingHours: OperatingHoursDto?
    let rating: Double
    let totalReviews: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, phone, building, floor, latitude, longitude, rating
        case imageUrl = "image_url"
        case vendorId = "vendor_id"
        case isOpen = "is_open"
        case isActive = "is_active"
        case locationDescription = "location_description"
        case operatingHours = "operating_hours"
        case totalReviews = "total_reviews"
    }
}

nonisolated struct OperatingHoursDto: Decodable, Sendable {
    let openTime: String
    let closeTime: String
    let daysOpen: [String]

    enum CodingKeys: String, CodingKey {
        case openTime = "open_time"
        case closeTime = "close_time"
        case daysOpen = "days_open"
    }
}

// MARK: - Food DTOs (matching actual Supabase schema + relationships)

nonisolated struct FoodItemDto: Decodable, Sendable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String?
    let price: Double
    let outletId: String
    let categoryId: String
    let isVeg: Bool?
    let isAvailable: Bool
    let prepTimeMinutes: Int
    let rating: Double
    let totalReviews: Int
    let ingredients: [String]?
    let tags: [String]?
    let calories: Int?
    let isPopular: Bool
    let isRecommended: Bool
    let outlet: OutletRefDto?
    let category: CategoryRefDto?
    let variants: [FoodVariantDto]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, price, rating, ingredients, tags, calories, outlet, category, variants
        case imageUrl = "image_url"
        case outletId = "outlet_id"
        case categoryId = "category_id"
        case isVeg = "is_veg"
        case isAvailable = "is_available"
        case prepTimeMinutes = "prep_time_minutes"
        case totalReviews = "total_reviews"
        case isPopular = "is_popular"
        case isRecommended = "is_recommended"
    }
}

nonisolated struct OutletRefDto: Decodable, Sendable {
    let name: String
}

nonisolated struct CategoryRefDto: Decodable, Sendable {
    let name: String
    let emoji: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, emoji
        case imageUrl = "image_url"
    }
}

nonisolated struct FoodVariantDto: Decodable, Sendable {
    let id: String
    let name: String
    let isRequired: Bool
    let maxSelections: Int
    let options: [FoodVariantOptionDto]?

    enum CodingKeys: String, CodingKey {
        case id, name, options
        case isRequired = "is_required"
        case maxSelections = "max_selections"
    }
}

nonisolated struct FoodVariantOptionDto: Decodable, Sendable {
    let id: String
    let name: String
    let extraPrice: Double

    enum CodingKeys: String, CodingKey {
        case id, name
        case extraPrice = "extra_price"
    }
}

// MARK: - Category DTO

nonisolated struct CategoryDto: Decodable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji
        case imageUrl = "image_url"
    }
}

// MARK: - RPC Parameter DTOs

nonisolated struct SearchFoodParams: Encodable, Sendable {
    let pQuery: String
    let pOutletId: String?
    let pCategory: String?
    let pIsVeg: Bool?
    let pMaxPrice: Double?
    let pAvailableOnly: Bool

    enum CodingKeys: String, CodingKey {
        case pQuery = "p_query"
        case pOutletId = "p_outlet_id"
        case pCategory = "p_category"
        case pIsVeg = "p_is_veg"
        case pMaxPrice = "p_max_price"
        case pAvailableOnly = "p_available_only"
    }
}

nonisolated struct FavoriteInsert: Encodable, Sendable {
    let userId: String
    let foodItemId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case foodItemId = "food_item_id"
    }
}

nonisolated struct FavRowDto: Decodable, Sendable {
    let foodItemId: String

    enum CodingKeys: String, CodingKey {
        case foodItemId = "food_item_id"
    }
}

// MARK: - Vendor DTOs

nonisolated struct OutletIdDto: Decodable, Sendable {
    let id: String
}
