import Foundation

/// A food item on an outlet's menu.
nonisolated struct FoodItem: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String?
    let price: Double
    let outletId: String
    let outletName: String
    let category: String
    let isVeg: Bool
    let isAvailable: Bool
    let prepTimeMinutes: Int
    let rating: Double
    let totalReviews: Int
    let ingredients: [String]
    let customizations: [FoodCustomization]
    let tags: [String]
    let calories: Int?
    let isPopular: Bool
    let isRecommended: Bool
    var isFavorite: Bool = false
}

/// A customization group, e.g. "Spice Level" with selectable options.
nonisolated struct FoodCustomization: Sendable, Hashable, Identifiable, Codable {
    let id: String
    let name: String
    let options: [CustomizationOption]
    let isRequired: Bool
    let maxSelections: Int
}

nonisolated struct CustomizationOption: Sendable, Hashable, Identifiable, Codable {
    let id: String
    let name: String
    let extraPrice: Double
}

nonisolated struct FoodCategory: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let emoji: String
    let imageUrl: String?
}

/// One outlet section on the category results screen: an outlet that
/// currently offers available dishes in the category, with those dishes.
/// Outlets with zero matching dishes never appear.
nonisolated struct CategoryOutlet: Sendable, Hashable, Identifiable {
    let outletId: String
    let outletName: String
    var dishes: [FoodItem]

    var id: String { outletId }
    var dishCount: Int { dishes.count }
    var fromPrice: Double? { dishes.map(\.price).min() }
}

/// Search / filter parameters.
nonisolated struct FoodSearchFilter: Sendable, Equatable {
    var query: String = ""
    var category: String? = nil
    var outletId: String? = nil
    var isVeg: Bool? = nil
    var maxPrice: Double? = nil
    var minRating: Double? = nil
    var maxPrepTimeMinutes: Int? = nil
    var availableOnly: Bool = true
    var sortBy: SortOption = .relevance
}

nonisolated enum SortOption: String, Sendable, CaseIterable, Identifiable {
    case relevance = "RELEVANCE"
    case priceLowToHigh = "PRICE_LOW_TO_HIGH"
    case priceHighToLow = "PRICE_HIGH_TO_LOW"
    case rating = "RATING"
    case prepTime = "PREP_TIME"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relevance: return "Relevance"
        case .priceLowToHigh: return "Price: Low to High"
        case .priceHighToLow: return "Price: High to Low"
        case .rating: return "Rating"
        case .prepTime: return "Prep Time"
        }
    }
}
