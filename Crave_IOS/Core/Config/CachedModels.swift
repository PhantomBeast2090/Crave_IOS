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

// MARK: - Cart (local source of truth, synced to backend by SupabaseCartRepository)

@Model
final class CartItemEntity {
    @Attribute(.unique) var id: String
    var foodItemId: String
    var foodName: String
    var foodImageUrl: String?
    var outletId: String
    var outletName: String
    /// Base unit price (customization extras stored per-selection below).
    var price: Double
    var quantity: Int
    var isVeg: Bool
    var specialInstructions: String?
    /// JSON-encoded `[SelectedCustomization]`.
    var customizationsData: Data
    /// Dedup key: food + sorted option ids (same key ⇒ merge quantities).
    var customizationKey: String
    var createdAt: Date = Date()

    init(
        id: String = UUID().uuidString,
        foodItemId: String,
        foodName: String,
        foodImageUrl: String?,
        outletId: String,
        outletName: String,
        price: Double,
        quantity: Int,
        isVeg: Bool,
        specialInstructions: String? = nil,
        customizations: [SelectedCustomization] = []
    ) {
        self.id = id
        self.foodItemId = foodItemId
        self.foodName = foodName
        self.foodImageUrl = foodImageUrl
        self.outletId = outletId
        self.outletName = outletName
        self.price = price
        self.quantity = quantity
        self.isVeg = isVeg
        self.specialInstructions = specialInstructions
        self.customizationsData = (try? JSONEncoder().encode(customizations)) ?? Data()
        self.customizationKey = CartMath.customizationKey(customizations)
    }

    var customizations: [SelectedCustomization] {
        (try? JSONDecoder().decode([SelectedCustomization].self, from: customizationsData)) ?? []
    }

    /// Unit price including customization extras, times quantity.
    var itemTotal: Double {
        (price + customizations.reduce(0) { $0 + $1.extraPrice }) * Double(quantity)
    }

    func toCartItem() -> CartItem {
        CartItem(
            id: id,
            foodItemId: foodItemId,
            foodName: foodName,
            foodImageUrl: foodImageUrl,
            outletId: outletId,
            price: price,
            quantity: quantity,
            selectedCustomizations: customizations,
            isVeg: isVeg,
            specialInstructions: specialInstructions
        )
    }
}

// MARK: - Orders (backend is authoritative; entities are an offline cache)

@Model
final class OrderEntity {
    @Attribute(.unique) var id: String
    var orderNumber: String
    var userId: String
    var vendorId: String
    var outletId: String
    var outletName: String
    var items: [OrderItemEntity]
    var subtotal: Double
    var tax: Double
    var total: Double
    var status: OrderStatus
    var slotDate: String?
    var slotStartTime: String?
    var slotEndTime: String?
    var estimatedPrepMinutes: Int
    var actualPrepMinutes: Int?
    var createdAt: Date = Date()
    var placedAt: Date?
    var acceptedAt: Date?
    var preparingAt: Date?
    var readyAt: Date?
    var pickedUpAt: Date?
    var cancelledAt: Date?
    var cancellationReason: String?
    var paymentStatus: PaymentStatus
    var paymentMethod: PaymentMethod
    var specialInstructions: String?
    var qrToken: String?

    init(
        id: String = UUID().uuidString,
        orderNumber: String,
        userId: String = "",
        vendorId: String = "",
        outletId: String = "",
        outletName: String = "",
        items: [OrderItemEntity] = [],
        subtotal: Double,
        tax: Double,
        total: Double,
        status: OrderStatus,
        slotDate: String? = nil,
        slotStartTime: String? = nil,
        slotEndTime: String? = nil,
        estimatedPrepMinutes: Int,
        actualPrepMinutes: Int? = nil,
        paymentStatus: PaymentStatus,
        paymentMethod: PaymentMethod,
        specialInstructions: String? = nil,
        qrToken: String? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.userId = userId
        self.vendorId = vendorId
        self.outletId = outletId
        self.outletName = outletName
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.status = status
        self.slotDate = slotDate
        self.slotStartTime = slotStartTime
        self.slotEndTime = slotEndTime
        self.estimatedPrepMinutes = estimatedPrepMinutes
        self.actualPrepMinutes = actualPrepMinutes
        self.paymentStatus = paymentStatus
        self.paymentMethod = paymentMethod
        self.specialInstructions = specialInstructions
        self.qrToken = qrToken
    }
}

@Model
final class OrderItemEntity {
    @Attribute(.unique) var id: String
    var foodItemId: String
    var foodName: String
    var foodImageUrl: String?
    var quantity: Int
    var unitPrice: Double
    var totalPrice: Double
    var customizations: [String]
    var isVeg: Bool

    init(
        id: String = UUID().uuidString,
        foodItemId: String,
        foodName: String,
        foodImageUrl: String?,
        quantity: Int,
        unitPrice: Double,
        totalPrice: Double? = nil,
        customizations: [String] = [],
        isVeg: Bool
    ) {
        self.id = id
        self.foodItemId = foodItemId
        self.foodName = foodName
        self.foodImageUrl = foodImageUrl
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice ?? unitPrice * Double(quantity)
        self.customizations = customizations
        self.isVeg = isVeg
    }
}
