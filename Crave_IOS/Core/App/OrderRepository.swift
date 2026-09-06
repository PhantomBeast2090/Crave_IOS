import Foundation

// MARK: - Order Repository Protocol (mirrors Android OrderRepository)

protocol OrderRepository: Sendable {
    // MARK: Student reads

    /// Stream cached orders (emits on refresh + realtime updates).
    func observeOrders() -> AsyncStream<[Order]>

    /// Fetch orders from the backend and refresh the cache.
    func refreshOrders() async throws -> [Order]

    /// Fetch a single order with slot + items + customizations.
    func getOrderById(_ orderId: String) async throws -> Order

    /// Active order for the home "Active Order" card, if any.
    func activeOrder() async -> Order?

    // MARK: Slots

    /// Pickup slots for an outlet on a date ("yyyy-MM-dd").
    func getPickupSlots(outletId: String, date: String) async throws -> [PickupSlot]

    // MARK: Placement

    /// Find the backend cart id for the current user (throws when missing).
    func backendCartId() async throws -> String

    /// Call `place_order` and return the full created order.
    /// Never clears the cart — the caller does that after confirmation.
    func placeOrder(pickupSlotId: String, paymentMethod: PaymentMethod) async throws -> Order

    /// Cancel a PLACED order (student). Reason is required by the trigger path.
    func cancelOrder(orderId: String, reason: String) async throws -> Order

    // MARK: Pickup token

    /// Backend pickup token for an order. Throws when used/missing.
    func getPickupToken(orderId: String) async throws -> (token: String, expiresAt: String?)

    // MARK: Realtime

    /// Live status updates for one order (seeded with the cached status).
    func observeOrderStatus(orderId: String) -> AsyncStream<OrderStatus>

    // MARK: Vendor

    func getVendorOrders(status: OrderStatus?) async throws -> [Order]
    func acceptOrder(orderId: String) async throws -> Order
    func rejectOrder(orderId: String, reason: String) async throws -> Order
    func startPreparing(orderId: String) async throws -> Order
    func markReady(orderId: String) async throws -> Order
    /// Verify a scanned QR token → returns the picked-up order.
    func confirmPickup(qrToken: String) async throws -> Order
}
