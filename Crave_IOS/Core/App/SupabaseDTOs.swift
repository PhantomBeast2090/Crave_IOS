import Foundation

// MARK: - Decoding helpers
//
// PostgREST / RPC payloads are not perfectly uniform:
// - `operating_hours` default JSON in the DB uses camelCase keys
//   (openTime/closeTime/daysOpen) while hand-written rows may use snake_case.
// - `DECIMAL` columns may arrive as JSON numbers *or* strings.
// - Embedded resources are keyed by table name (`outlets`, `food_variants`,
//   `food_variant_options`) unless the query aliases them — the decoders below
//   accept both the alias and the raw table name.
// - The `search_food` RPC returns a *flat* shape (outlet_name/category_name,
//   no variants/tags/calories/total_reviews) which must still decode.

nonisolated func decodeFlexibleDouble(_ container: KeyedDecodingContainer<FoodItemDto.CodingKeys>, keys: [FoodItemDto.CodingKeys], defaultValue: Double = 0) -> Double {
    for key in keys {
        let d: Double? = try? container.decodeIfPresent(Double.self, forKey: key)
        if let d { return d }
        let i: Int? = try? container.decodeIfPresent(Int.self, forKey: key)
        if let i { return Double(i) }
        let s: String? = try? container.decodeIfPresent(String.self, forKey: key)
        if let s, let d = Double(s) { return d }
    }
    return defaultValue
}

nonisolated func decodeFlexibleInt(_ container: KeyedDecodingContainer<FoodItemDto.CodingKeys>, keys: [FoodItemDto.CodingKeys], defaultValue: Int = 0) -> Int {
    for key in keys {
        let v: Int? = try? container.decodeIfPresent(Int.self, forKey: key)
        if let v { return v }
        let d: Double? = try? container.decodeIfPresent(Double.self, forKey: key)
        if let d { return Int(d) }
        let s: String? = try? container.decodeIfPresent(String.self, forKey: key)
        if let s, let i = Int(s) { return i }
        if let s, let d = Double(s) { return Int(d) }
    }
    return defaultValue
}

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

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        imageUrl = try? c.decodeIfPresent(String.self, forKey: .imageUrl)
        vendorId = try? c.decodeIfPresent(String.self, forKey: .vendorId)
        isOpen = (try? c.decodeIfPresent(Bool.self, forKey: .isOpen)) ?? false
        isActive = (try? c.decodeIfPresent(Bool.self, forKey: .isActive)) ?? true
        phone = try? c.decodeIfPresent(String.self, forKey: .phone)
        building = try? c.decodeIfPresent(String.self, forKey: .building)
        floor = try? c.decodeIfPresent(String.self, forKey: .floor)
        locationDescription = try? c.decodeIfPresent(String.self, forKey: .locationDescription)
        latitude = Self.flexDouble(c, key: .latitude)
        longitude = Self.flexDouble(c, key: .longitude)
        operatingHours = try? c.decodeIfPresent(OperatingHoursDto.self, forKey: .operatingHours)
        rating = Self.flexDouble(c, key: .rating) ?? 0
        totalReviews = Self.flexInt(c, key: .totalReviews)
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        let v: Double? = try? c.decodeIfPresent(Double.self, forKey: key)
        if let v { return v }
        let i: Int? = try? c.decodeIfPresent(Int.self, forKey: key)
        if let i { return Double(i) }
        let s: String? = try? c.decodeIfPresent(String.self, forKey: key)
        if let s { return Double(s) }
        return nil
    }

    private static func flexInt(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int {
        let v: Int? = try? c.decodeIfPresent(Int.self, forKey: key)
        if let v { return v }
        let d: Double? = try? c.decodeIfPresent(Double.self, forKey: key)
        if let d { return Int(d) }
        let s: String? = try? c.decodeIfPresent(String.self, forKey: key)
        if let s { return Int(s) ?? Int(Double(s) ?? 0) }
        return 0
    }
}

nonisolated struct OperatingHoursDto: Decodable, Sendable {
    let openTime: String
    let closeTime: String
    let daysOpen: [String]

    init(openTime: String, closeTime: String, daysOpen: [String]) {
        self.openTime = openTime
        self.closeTime = closeTime
        self.daysOpen = daysOpen
    }

    enum CodingKeys: String, CodingKey {
        case openTime = "open_time"
        case closeTime = "close_time"
        case daysOpen = "days_open"
        case openTimeCamel = "openTime"
        case closeTimeCamel = "closeTime"
        case daysOpenCamel = "daysOpen"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openTime = (try? c.decodeIfPresent(String.self, forKey: .openTime))
            ?? (try? c.decodeIfPresent(String.self, forKey: .openTimeCamel))
            ?? "08:00"
        closeTime = (try? c.decodeIfPresent(String.self, forKey: .closeTime))
            ?? (try? c.decodeIfPresent(String.self, forKey: .closeTimeCamel))
            ?? "22:00"
        daysOpen = (try? c.decodeIfPresent([String].self, forKey: .daysOpen))
            ?? (try? c.decodeIfPresent([String].self, forKey: .daysOpenCamel))
            ?? ["Mon", "Tue", "Wed", "Thu", "Fri"]
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
        // Raw PostgREST embed keys (when the query does not alias)
        case outlets, categories
        case foodVariants = "food_variants"
        // Flat RPC keys from search_food()
        case outletName = "outlet_name"
        case categoryName = "category_name"
        case categoryEmoji = "category_emoji"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        imageUrl = try? c.decodeIfPresent(String.self, forKey: .imageUrl)
        price = decodeFlexibleDouble(c, keys: [.price])
        outletId = (try? c.decodeIfPresent(String.self, forKey: .outletId)) ?? ""
        categoryId = (try? c.decodeIfPresent(String.self, forKey: .categoryId)) ?? ""
        isVeg = try? c.decodeIfPresent(Bool.self, forKey: .isVeg)
        isAvailable = (try? c.decodeIfPresent(Bool.self, forKey: .isAvailable)) ?? true
        prepTimeMinutes = decodeFlexibleInt(c, keys: [.prepTimeMinutes], defaultValue: 5)
        rating = decodeFlexibleDouble(c, keys: [.rating])
        totalReviews = decodeFlexibleInt(c, keys: [.totalReviews])
        ingredients = try? c.decodeIfPresent([String].self, forKey: .ingredients)
        tags = try? c.decodeIfPresent([String].self, forKey: .tags)
        if let cal = try? c.decodeIfPresent(Int.self, forKey: .calories) {
            calories = cal
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .calories) {
            calories = Int(d)
        } else {
            calories = nil
        }
        isPopular = (try? c.decodeIfPresent(Bool.self, forKey: .isPopular)) ?? false
        isRecommended = (try? c.decodeIfPresent(Bool.self, forKey: .isRecommended)) ?? false

        // Nested outlet: prefer alias, fall back to raw table key, then flat RPC field.
        if let o = try? c.decodeIfPresent(OutletRefDto.self, forKey: .outlet) {
            outlet = o
        } else if let o = try? c.decodeIfPresent(OutletRefDto.self, forKey: .outlets) {
            outlet = o
        } else if let flatName: String = (try? c.decodeIfPresent(String.self, forKey: .outletName)) ?? nil {
            outlet = OutletRefDto(name: flatName)
        } else {
            outlet = nil
        }

        // Nested category: same fallback chain.
        if let cat = try? c.decodeIfPresent(CategoryRefDto.self, forKey: .category) {
            category = cat
        } else if let cat = try? c.decodeIfPresent(CategoryRefDto.self, forKey: .categories) {
            category = cat
        } else if let flatName: String = (try? c.decodeIfPresent(String.self, forKey: .categoryName)) ?? nil {
            let emoji: String = (try? c.decodeIfPresent(String.self, forKey: .categoryEmoji)) ?? ""
            category = CategoryRefDto(name: flatName, emoji: emoji, imageUrl: nil)
        } else {
            category = nil
        }

        // Variants: alias first, then raw table key.
        if let v = try? c.decodeIfPresent([FoodVariantDto].self, forKey: .variants) {
            variants = v
        } else if let v = try? c.decodeIfPresent([FoodVariantDto].self, forKey: .foodVariants) {
            variants = v
        } else {
            variants = nil
        }
    }
}

nonisolated struct OutletRefDto: Decodable, Sendable {
    let name: String

    init(name: String) { self.name = name }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
    }

    enum CodingKeys: String, CodingKey { case name }
}

nonisolated struct CategoryRefDto: Decodable, Sendable {
    let name: String
    let emoji: String
    let imageUrl: String?

    init(name: String, emoji: String, imageUrl: String?) {
        self.name = name
        self.emoji = emoji
        self.imageUrl = imageUrl
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        emoji = (try? c.decodeIfPresent(String.self, forKey: .emoji)) ?? ""
        imageUrl = try? c.decodeIfPresent(String.self, forKey: .imageUrl)
    }

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
        case rawOptions = "food_variant_options"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        isRequired = (try? c.decodeIfPresent(Bool.self, forKey: .isRequired)) ?? false
        let maxInt: Int? = try? c.decodeIfPresent(Int.self, forKey: .maxSelections)
        let maxDouble: Double? = try? c.decodeIfPresent(Double.self, forKey: .maxSelections)
        if let maxInt {
            maxSelections = maxInt
        } else if let maxDouble {
            maxSelections = Int(maxDouble)
        } else {
            maxSelections = 1
        }
        if let o = try? c.decodeIfPresent([FoodVariantOptionDto].self, forKey: .options) {
            options = o
        } else if let o = try? c.decodeIfPresent([FoodVariantOptionDto].self, forKey: .rawOptions) {
            options = o
        } else {
            options = nil
        }
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

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        let priceDouble: Double? = try? c.decodeIfPresent(Double.self, forKey: .extraPrice)
        let priceInt: Int? = try? c.decodeIfPresent(Int.self, forKey: .extraPrice)
        let priceString: String? = try? c.decodeIfPresent(String.self, forKey: .extraPrice)
        if let priceDouble {
            extraPrice = priceDouble
        } else if let priceInt {
            extraPrice = Double(priceInt)
        } else if let priceString, let d = Double(priceString) {
            extraPrice = d
        } else {
            extraPrice = 0
        }
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

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        emoji = (try? c.decodeIfPresent(String.self, forKey: .emoji)) ?? ""
        imageUrl = try? c.decodeIfPresent(String.self, forKey: .imageUrl)
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

// MARK: - Decoding diagnostics

/// Human-readable description for decoding failures so the UI never has to
/// surface a bare "data couldn't be read because it is missing".
nonisolated func describeDecodingError(_ error: Error) -> String {
    guard let decodingError = error as? DecodingError else { return error.localizedDescription }
    switch decodingError {
    case .keyNotFound(let key, let context):
        return "Missing key '\(key.stringValue)' — \(context.debugDescription)"
    case .valueNotFound(let type, let context):
        return "Missing value of type \(type) — \(context.debugDescription)"
    case .typeMismatch(let type, let context):
        return "Type mismatch for \(type) — \(context.debugDescription)"
    case .dataCorrupted(let context):
        return "Corrupted data — \(context.debugDescription)"
    @unknown default:
        return error.localizedDescription
    }
}
