import Foundation
import SwiftData

@Model
final class CachedOutlet {
    @Attribute(.unique) var id: String
    var name: String
    var desc: String
    var imageUrl: String?
    var building: String
    var floor: String
    var locationDescription: String
    var latitude: Double?
    var longitude: Double?
    var isOpen: Bool
    var openTime: String
    var closeTime: String
    var daysOpenData: Data  // JSON encoded [String]
    var rating: Double
    var totalReviews: Int
    var vendorId: String
    var isActive: Bool
    var phone: String?
    var lastUpdated: Date = Date()
    
    init(outlet: Outlet) {
        self.id = outlet.id
        self.name = outlet.name
        self.desc = outlet.description
        self.imageUrl = outlet.imageUrl
        self.building = outlet.location.building
        self.floor = outlet.location.floor
        self.locationDescription = outlet.location.description
        self.latitude = outlet.location.latitude
        self.longitude = outlet.location.longitude
        self.isOpen = outlet.isOpen
        self.openTime = outlet.operatingHours.openTime
        self.closeTime = outlet.operatingHours.closeTime
        self.daysOpenData = (try? JSONEncoder().encode(outlet.operatingHours.daysOpen)) ?? Data()
        self.rating = outlet.rating
        self.totalReviews = outlet.totalReviews
        self.vendorId = outlet.vendorId
        self.isActive = outlet.isActive
        self.phone = outlet.phone
    }
    
    func toOutlet() -> Outlet {
        let daysOpen = (try? JSONDecoder().decode([String].self, from: daysOpenData)) ?? []
        return Outlet(
            id: id,
            name: name,
            description: desc,
            imageUrl: imageUrl,
            location: OutletLocation(
                building: building,
                floor: floor,
                description: locationDescription,
                latitude: latitude,
                longitude: longitude
            ),
            isOpen: isOpen,
            operatingHours: OperatingHours(
                openTime: openTime,
                closeTime: closeTime,
                daysOpen: daysOpen
            ),
            currentQueueSize: 0,
            estimatedWaitMinutes: 0,
            categories: [],
            rating: rating,
            totalReviews: totalReviews,
            vendorId: vendorId,
            isActive: isActive,
            phone: phone
        )
    }
}

@Model
final class CachedFoodItem {
    @Attribute(.unique) var id: String
    var name: String
    var desc: String
    var imageUrl: String?
    var price: Double
    var outletId: String
    var outletName: String
    var category: String
    var isVeg: Bool
    var isAvailable: Bool
    var prepTimeMinutes: Int
    var rating: Double
    var totalReviews: Int
    var ingredientsData: Data  // JSON encoded [String]
    var customizationsData: Data  // JSON encoded [FoodCustomization]
    var tagsData: Data  // JSON encoded [String]
    var calories: Int?
    var isPopular: Bool
    var isRecommended: Bool
    var isFavorite: Bool
    var lastUpdated: Date = Date()
    
    init(foodItem: FoodItem) {
        self.id = foodItem.id
        self.name = foodItem.name
        self.desc = foodItem.description
        self.imageUrl = foodItem.imageUrl
        self.price = foodItem.price
        self.outletId = foodItem.outletId
        self.outletName = foodItem.outletName
        self.category = foodItem.category
        self.isVeg = foodItem.isVeg
        self.isAvailable = foodItem.isAvailable
        self.prepTimeMinutes = foodItem.prepTimeMinutes
        self.rating = foodItem.rating
        self.totalReviews = foodItem.totalReviews
        self.ingredientsData = (try? JSONEncoder().encode(foodItem.ingredients)) ?? Data()
        self.customizationsData = (try? JSONEncoder().encode(foodItem.customizations)) ?? Data()
        self.tagsData = (try? JSONEncoder().encode(foodItem.tags)) ?? Data()
        self.calories = foodItem.calories
        self.isPopular = foodItem.isPopular
        self.isRecommended = foodItem.isRecommended
        self.isFavorite = foodItem.isFavorite
    }
    
    func toFoodItem() -> FoodItem {
        let ingredients = (try? JSONDecoder().decode([String].self, from: ingredientsData)) ?? []
        let customizations = (try? JSONDecoder().decode([FoodCustomization].self, from: customizationsData)) ?? []
        let tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        
        return FoodItem(
            id: id,
            name: name,
            description: desc,
            imageUrl: imageUrl,
            price: price,
            outletId: outletId,
            outletName: outletName,
            category: category,
            isVeg: isVeg,
            isAvailable: isAvailable,
            prepTimeMinutes: prepTimeMinutes,
            rating: rating,
            totalReviews: totalReviews,
            ingredients: ingredients,
            customizations: customizations,
            tags: tags,
            calories: calories,
            isPopular: isPopular,
            isRecommended: isRecommended,
            isFavorite: isFavorite
        )
    }
}
