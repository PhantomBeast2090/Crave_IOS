import Foundation

/// A cart is always associated with a SINGLE outlet.
/// Adding items from a different outlet requires clearing the cart first.
nonisolated struct Cart: Sendable, Hashable {
    let outletId: String
    let outletName: String
    var items: [CartItem]
    var subtotal: Double
    var tax: Double
    var total: Double
    var estimatedPrepMinutes: Int

    var isEmpty: Bool { items.isEmpty }
    var totalItems: Int { items.reduce(0) { $0 + $1.quantity } }
}

nonisolated struct CartItem: Sendable, Hashable, Identifiable {
    let id: String
    let foodItemId: String
    let foodName: String
    let foodImageUrl: String?
    let outletId: String
    let price: Double
    var quantity: Int
    var selectedCustomizations: [SelectedCustomization]
    let isVeg: Bool
    let specialInstructions: String?

    /// Unit price including customization extras, times quantity.
    var itemTotal: Double {
        (price + selectedCustomizations.reduce(0) { $0 + $1.extraPrice }) * Double(quantity)
    }
}

nonisolated struct SelectedCustomization: Sendable, Hashable, Identifiable {
    let customizationId: String
    let customizationName: String
    let optionId: String
    let optionName: String
    let extraPrice: Double

    var id: String { "\(customizationId)-\(optionId)" }
}
