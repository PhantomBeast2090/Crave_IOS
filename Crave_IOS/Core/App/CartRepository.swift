import Foundation

// MARK: - Cart Repository Protocol
//
// - Local SwiftData is the source of truth for the UI.
// - Every mutation syncs to the backend (carts / cart_items /
//   cart_item_customizations) so the cart survives app restarts and is
//   visible to `place_order`.
// - Multi-outlet carts are supported: lines group into outlet sections for
//   display, per-section slots, and per-section order placement.

protocol CartRepository: Sendable {
    /// Stream cart snapshots (emits on every local mutation + backend sync).
    func observeCart() -> AsyncStream<Cart?>

    /// Current snapshot without subscribing.
    func currentCart() async -> Cart?

    /// Outlet id of the current cart's first section, if any.
    func cartOutletId() async -> String?

    /// Pull the backend cart into the local store (call after login).
    func syncFromBackend() async throws

    /// Add an item from any outlet. Lines from different outlets coexist in
    /// outlet sections — no conflict, no clearing.
    @discardableResult
    func addItem(
        foodItem: FoodItem,
        outletName: String,
        quantity: Int,
        customizations: [SelectedCustomization],
        specialInstructions: String?
    ) async throws -> Cart

    /// Set quantity (<= 0 removes the line).
    @discardableResult
    func updateQuantity(cartItemId: String, quantity: Int) async throws -> Cart

    /// Remove a line.
    @discardableResult
    func removeItem(cartItemId: String) async throws -> Cart

    /// Set a line's pickup slot (stored locally; pushed with the cart).
    /// Slot validity against the outlet's slots is checked by cart/checkout
    /// view models; the server re-validates authoritatively at placement.
    @discardableResult
    func setSlot(cartItemId: String, slotId: String?) async throws -> Cart

    /// Clear local + backend cart.
    func clearCart() async throws

    /// Clear one outlet section (local lines + backend row for that outlet).
    /// Used after an outlet section's order is verified, keeping siblings.
    func clearSection(outletId: String) async throws

    /// Clear the local store only (sign-out). Never touches the backend —
    /// the server cart belongs to the user and survives sign-out.
    func clearLocal() async throws

    /// Push the local cart to the backend. Throws on failure — checkout
    /// calls this authoritatively before `place_order`.
    func pushToBackend() async throws
}

// MARK: - Cart Errors

nonisolated enum CartError: LocalizedError, Sendable, Equatable {
    case invalidQuantity
    case unavailable
    case emptyCart
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "Quantity must be at least 1."
        case .unavailable:
            return "This food item is not available right now."
        case .emptyCart:
            return "Your cart is empty."
        case .notSignedIn:
            return "Please sign in to use the cart."
        }
    }
}

// MARK: - Local Store (protocol for testability)

@MainActor
protocol CartLocalStore: Sendable {
    func loadAll() async -> [CartItemEntity]
    func upsert(_ item: CartItemEntity) async throws
    func delete(id: String) async throws
    func clear() async throws
    /// Stream cart snapshots. The element is the Sendable `Cart?` value (not
    /// `CartItemEntity`): SwiftData `@Model` instances are context-confined
    /// and must never cross actor/Sendable boundaries.
    func observe() -> AsyncStream<Cart?>
    func notifyChanged() async
}

// MARK: - Cart math (single source of truth, unit-tested)

nonisolated enum CartMath: Sendable {
    /// GST applied client-side for display; the server recomputes authoritatively.
    static let taxRate = 0.05
    static let maxQuantity = 10

    static func totals(for items: [CartItem]) -> (subtotal: Double, tax: Double, total: Double) {
        let subtotal = items.reduce(0) { $0 + $1.itemTotal }
        let tax = subtotal * taxRate
        return (subtotal, tax, subtotal + tax)
    }

    static func snapshot(outletId: String, outletName: String, items: [CartItem]) -> Cart {
        let t = totals(for: items)
        return Cart(
            outletId: outletId,
            outletName: outletName,
            items: items,
            subtotal: t.subtotal,
            tax: t.tax,
            total: t.total,
            estimatedPrepMinutes: items.count * 5
        )
    }

    /// Group lines into outlet sections (first-seen outlet order), each with
    /// its own totals. Single-outlet carts yield exactly one section.
    static func groupedSections(items: [CartItem]) -> [OutletCartSection] {
        var order: [String] = []
        var groups: [String: (name: String, items: [CartItem])] = [:]
        for item in items {
            if groups[item.outletId] == nil {
                groups[item.outletId] = (item.outletName, [])
                order.append(item.outletId)
            }
            groups[item.outletId]?.items.append(item)
        }
        return order.compactMap { id in
            guard let group = groups[id] else { return nil }
            let t = totals(for: group.items)
            return OutletCartSection(
                outletId: id,
                outletName: group.name,
                items: group.items,
                subtotal: t.subtotal,
                tax: t.tax,
                total: t.total,
                estimatedPrepMinutes: group.items.count * 5
            )
        }
    }

    /// Dedup key: same food + same customization options merge quantities.
    static func customizationKey(_ customizations: [SelectedCustomization]) -> String {
        customizations.map { $0.optionId }.sorted().joined(separator: ",")
    }
}
