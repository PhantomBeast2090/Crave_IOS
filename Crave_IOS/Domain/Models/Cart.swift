import Foundation

/// A cart holds items across outlets, grouped into outlet sections for
/// display, slots, and checkout. Single-outlet carts are the one-section
/// special case (see `sections`).
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

    /// Items grouped by outlet, preserving first-seen outlet order.
    var sections: [OutletCartSection] {
        CartMath.groupedSections(items: items)
    }

    /// All outlet ids present, in first-seen order.
    var outletIds: [String] {
        var seen: [String] = []
        for item in items where !seen.contains(item.outletId) {
            seen.append(item.outletId)
        }
        return seen
    }
}

/// One outlet's lines within a cart: display, per-section slot selection,
/// and per-section order placement all key off this unit.
nonisolated struct OutletCartSection: Sendable, Hashable, Identifiable {
    let outletId: String
    let outletName: String
    var items: [CartItem]
    var subtotal: Double
    var tax: Double
    var total: Double
    var estimatedPrepMinutes: Int

    var id: String { outletId }
    var totalItems: Int { items.reduce(0) { $0 + $1.quantity } }
    /// Slot ids chosen per item (nil = not yet chosen).
    var allSlotsChosen: Bool { items.allSatisfy { $0.slotId != nil } }
}

nonisolated struct CartItem: Sendable, Hashable, Identifiable {
    let id: String
    let foodItemId: String
    let foodName: String
    let foodImageUrl: String?
    let outletId: String
    var outletName: String = ""
    let price: Double
    var quantity: Int
    var selectedCustomizations: [SelectedCustomization]
    let isVeg: Bool
    let specialInstructions: String?
    /// Per-item pickup slot (chosen in cart/checkout). Nil until chosen.
    var slotId: String? = nil

    /// Unit price including customization extras, times quantity.
    var itemTotal: Double {
        (price + selectedCustomizations.reduce(0) { $0 + $1.extraPrice }) * Double(quantity)
    }
}

nonisolated struct SelectedCustomization: Sendable, Hashable, Identifiable, Codable {
    let customizationId: String
    let customizationName: String
    let optionId: String
    let optionName: String
    let extraPrice: Double

    var id: String { "\(customizationId)-\(optionId)" }
}
