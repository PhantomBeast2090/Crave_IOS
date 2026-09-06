import Foundation

// MARK: - Cart Repository Protocol
//
// Mirrors Android's CartRepository + cart use-cases:
// - Local SwiftData is the source of truth for the UI.
// - Every mutation syncs to the backend (carts / cart_items /
//   cart_item_customizations) so the cart survives app restarts and is
//   visible to `place_order`.
// - Single-outlet invariant enforced client-side (with a typed conflict
//   error so the UI can show Android's "Different Outlet" dialog) and
//   server-side by `enforce_cart_single_outlet`.

protocol CartRepository: Sendable {
    /// Stream cart snapshots (emits on every local mutation + backend sync).
    func observeCart() -> AsyncStream<Cart?>

    /// Current snapshot without subscribing.
    func currentCart() async -> Cart?

    /// Outlet id of the current cart, if any.
    func cartOutletId() async -> String?

    /// Pull the backend cart into the local store (call after login).
    func syncFromBackend() async throws

    /// Add an item. Throws `CartError.outletConflict` when the cart belongs
    /// to a different outlet.
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

    /// Clear local + backend cart.
    func clearCart() async throws

    /// Push the local cart to the backend. Throws on failure — checkout
    /// calls this authoritatively before `place_order`.
    func pushToBackend() async throws
}

// MARK: - Cart Errors

nonisolated enum CartError: LocalizedError, Sendable, Equatable {
    /// Cart belongs to another outlet — UI must confirm before clearing.
    case outletConflict(currentOutletName: String)
    case invalidQuantity
    case unavailable
    case emptyCart
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .outletConflict(let name):
            return "Your cart contains items from \(name). Clear cart and add from this outlet?"
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
    func observe() -> AsyncStream<[CartItemEntity]>
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

    /// Dedup key: same food + same customization options merge quantities.
    static func customizationKey(_ customizations: [SelectedCustomization]) -> String {
        customizations.map { $0.optionId }.sorted().joined(separator: ",")
    }
}
