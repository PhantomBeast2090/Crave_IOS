import Foundation
@testable import Crave_IOS

/// Minimal Sendable fakes for repository protocols, so ViewModel business
/// logic can be tested without the network. Only the members exercised by
/// current tests are functional; everything else returns empty values.

final class FakeOrders: OrderRepository, @unchecked Sendable {
    var placedOrders: [Order] = []
    var cancelledIds: [String] = []
    var placeError: Error?
    var slotToReturn: PickupSlot?

    private func makeOrder(id: String = UUID().uuidString) -> Order {
        Order(
            id: id, orderNumber: "GAG-TEST-1", userId: "user-1", vendorId: "vendor-1",
            outletId: "outlet-1", outletName: "Java Green", items: [],
            subtotal: 100, tax: 5, total: 105, status: .placed, pickupSlot: nil,
            estimatedPrepMinutes: 10, actualPrepMinutes: nil, createdAt: "",
            placedAt: nil, acceptedAt: nil, preparingAt: nil, readyAt: nil,
            pickedUpAt: nil, cancelledAt: nil, cancellationReason: nil,
            paymentStatus: .pending, paymentMethod: .online,
            specialInstructions: nil, qrToken: nil
        )
    }

    func observeOrders() -> AsyncStream<[Order]> {
        AsyncStream { $0.finish() }
    }

    func refreshOrders() async throws -> [Order] { placedOrders }
    func clearLocalCache() async { placedOrders = [] }
    func getOrderById(_ orderId: String) async throws -> Order { makeOrder(id: orderId) }
    func activeOrder() async -> Order? { placedOrders.first }

    func getPickupSlots(outletId: String, date: String) async throws -> [PickupSlot] {
        if let slot = slotToReturn { return [slot] }
        return []
    }

    func backendCartId() async throws -> String { "cart-1" }

    func placeOrder(pickupSlotId: String, paymentMethod: PaymentMethod) async throws -> Order {
        if let placeError { throw placeError }
        let order = makeOrder()
        placedOrders.append(order)
        return order
    }

    func cancelOrder(orderId: String, reason: String) async throws -> Order {
        cancelledIds.append(orderId)
        return makeOrder(id: orderId)
    }

    func getPickupToken(orderId: String) async throws -> (token: String, expiresAt: String?) {
        ("token", nil)
    }

    func observeOrderStatus(orderId: String) -> AsyncStream<OrderStatus> {
        AsyncStream { $0.finish() }
    }

    func getVendorOrders(status: OrderStatus?) async throws -> [Order] { [] }
    func acceptOrder(orderId: String) async throws -> Order { makeOrder(id: orderId) }
    func rejectOrder(orderId: String, reason: String) async throws -> Order { makeOrder(id: orderId) }
    func startPreparing(orderId: String) async throws -> Order { makeOrder(id: orderId) }
    func markReady(orderId: String) async throws -> Order { makeOrder(id: orderId) }
    func confirmPickup(qrToken: String) async throws -> Order { makeOrder() }
}

final class FakePayments: PaymentRepository, @unchecked Sendable {
    var verifyCalls: [PaymentVerificationRequest] = []
    /// Fail the next `count` verify calls, then succeed.
    var verifyFailuresRemaining = 0
    var isOnlinePaymentConfigured = true

    func createRazorpayOrder(orderId: String) async throws -> RazorpayOrderDetails {
        RazorpayOrderDetails(razorpayOrderId: "rzp-order-1", amount: 10500, keyId: "key-test", currency: "INR")
    }

    func verifyRazorpayPayment(_ request: PaymentVerificationRequest) async throws {
        verifyCalls.append(request)
        if verifyFailuresRemaining > 0 {
            verifyFailuresRemaining -= 1
            throw AppError.message("verify timeout")
        }
    }
}

final class FakeCart: CartRepository, @unchecked Sendable {
    var pushCount = 0
    var clearCount = 0
    var cart: Cart?

    func observeCart() -> AsyncStream<Cart?> {
        AsyncStream { $0.finish() }
    }

    func currentCart() async -> Cart? { cart }
    func cartOutletId() async -> String? { cart?.outletId }
    func syncFromBackend() async throws {}

    func addItem(foodItem: FoodItem, outletName: String, quantity: Int,
                 customizations: [SelectedCustomization],
                 specialInstructions: String?) async throws -> Cart {
        throw AppError.message("unimplemented in fake")
    }

    func updateQuantity(cartItemId: String, quantity: Int) async throws -> Cart {
        throw AppError.message("unimplemented in fake")
    }

    func removeItem(cartItemId: String) async throws -> Cart {
        throw AppError.message("unimplemented in fake")
    }

    func clearCart() async throws { clearCount += 1 }
    func clearLocal() async throws { clearCount += 1 }
    func pushToBackend() async throws { pushCount += 1 }
}

@MainActor
final class FakeSheet: PaymentSheetProvider {
    var result: RazorpaySheetResult = .cancelled
    nonisolated init() {}
    func pay(keyId: String, amountPaise: Int, razorpayOrderId: String,
             outletName: String, email: String?) async -> RazorpaySheetResult {
        result
    }
}

final class StubOutlets: OutletRepository, @unchecked Sendable {
    func observeOutlets() -> AsyncStream<[Outlet]> { AsyncStream { $0.finish() } }
    func refreshOutlets() async throws -> [Outlet] { [] }
    func refreshAllOutlets() async throws -> [Outlet] { [] }
    func getOutletById(_ outletId: String) async throws -> Outlet {
        throw AppError.message("unimplemented in stub")
    }
    func getNearbyOutlets(lat: Double, lng: Double) async throws -> [Outlet] { [] }
}

final class StubFood: FoodRepository, @unchecked Sendable {
    func searchFood(filter: FoodSearchFilter) async throws -> [FoodItem] { [] }
    func getFoodById(_ foodId: String) async throws -> FoodItem {
        throw AppError.message("unimplemented in stub")
    }
    func getMenuByOutlet(_ outletId: String) async throws -> [FoodItem] { [] }
    func getPopularFood() async throws -> [FoodItem] { [] }
    func getRecommendedFood() async throws -> [FoodItem] { [] }
    func getAllFood() async throws -> [FoodItem] { [] }
    func getCategories() async throws -> [FoodCategory] { [] }
    func observeFavorites() -> AsyncStream<[FoodItem]> { AsyncStream { $0.finish() } }
    func syncFavorites() async throws -> [FoodItem] { [] }
    func toggleFavorite(foodItemId: String) async throws -> Bool { false }
    func isFavorite(foodItemId: String) async throws -> Bool { false }
    func getVendorFoodItems() async throws -> [FoodItem] { [] }
    func updateFoodAvailability(foodId: String, isAvailable: Bool) async throws {}
    func updateFoodPrice(foodId: String, price: Double) async throws {}
}

final class StubNotifications: NotificationRepository, @unchecked Sendable {
    func observeNotifications() -> AsyncStream<[AppNotification]> { AsyncStream { $0.finish() } }
    func refreshNotifications() async throws -> [AppNotification] { [] }
    func unreadCount() async -> Int { 0 }
    func markAsRead(_ notificationId: String) async throws {}
}

final class StubAdmin: AdminRepository, @unchecked Sendable {
    func getSystemStats() async throws -> SystemStats {
        throw AppError.message("unimplemented in stub")
    }
    func toggleOutletStatus(outletId: String, isOpen: Bool) async throws {}
}
