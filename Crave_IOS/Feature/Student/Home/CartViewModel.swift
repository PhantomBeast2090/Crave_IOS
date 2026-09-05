import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CartViewModel {
    private let modelContext: ModelContext
    private(set) var items: [CartItemEntity] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCart()
    }
    
    var isEmpty: Bool { items.isEmpty }
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var subtotal: Double { items.reduce(0) { $0 + $1.totalPrice } }
    var tax: Double { subtotal * AppConfig.taxRate }
    var total: Double { subtotal + tax }
    
    func loadCart() {
        let descriptor = FetchDescriptor<CartItemEntity>()
        do {
            items = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load cart: \(error)")
        }
    }
    
    func addItem(_ foodItem: FoodItem, quantity: Int = 1, selectedCustomizations: [String: CustomizationOption] = [:]) {
        // Check if item already exists in cart with same customizations
        let customizationKey = selectedCustomizations.values.map { $0.id }.sorted().joined(separator: ",")
        
        if let existingIndex = items.firstIndex(where: { 
            $0.foodItemId == foodItem.id && $0.customizationKey == customizationKey 
        }) {
            items[existingIndex].quantity += quantity
            items[existingIndex].updateTotalPrice()
        } else {
            let entity = CartItemEntity(
                foodItemId: foodItem.id,
                foodName: foodItem.name,
                foodImageUrl: foodItem.imageUrl,
                unitPrice: foodItem.price,
                quantity: quantity,
                customizationKey: customizationKey,
                customizationNames: selectedCustomizations.values.map { $0.name },
                isVeg: foodItem.isVeg
            )
            modelContext.insert(entity)
            items.append(entity)
        }
        
        try? modelContext.save()
    }
    
    func updateQuantity(_ item: CartItemEntity, quantity: Int) {
        if quantity <= 0 {
            removeItem(item)
        } else {
            item.quantity = quantity
            item.updateTotalPrice()
            try? modelContext.save()
        }
    }
    
    func removeItem(_ item: CartItemEntity) {
        modelContext.delete(item)
        items.removeAll { $0.id == item.id }
        try? modelContext.save()
    }
    
    func clearCart() {
        for item in items {
            modelContext.delete(item)
        }
        items.removeAll()
        try? modelContext.save()
    }
}

@Model
final class CartItemEntity {
    var id: String = UUID().uuidString
    var foodItemId: String
    var foodName: String
    var foodImageUrl: String?
    var unitPrice: Double
    var quantity: Int
    var customizationKey: String
    var customizationNames: [String]
    var isVeg: Bool
    var createdAt: Date = Date()
    
    init(
        foodItemId: String,
        foodName: String,
        foodImageUrl: String?,
        unitPrice: Double,
        quantity: Int,
        customizationKey: String,
        customizationNames: [String],
        isVeg: Bool
    ) {
        self.foodItemId = foodItemId
        self.foodName = foodName
        self.foodImageUrl = foodImageUrl
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.customizationKey = customizationKey
        self.customizationNames = customizationNames
        self.isVeg = isVeg
    }
    
    var totalPrice: Double { unitPrice * Double(quantity) }
    
    func updateTotalPrice() {
        // Trigger recomputation
        self.quantity = quantity
    }
}
