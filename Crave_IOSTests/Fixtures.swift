import Foundation
@testable import Crave_IOS

/// Shared test fixtures: Sendable fakes for all repository protocols plus
/// builders for domain models, so ViewModel business logic can be tested
/// without the network. Only the members exercised by current tests are
/// functional; everything else returns empty values.

final class FakeOrders: OrderRepository, @unchecked Sendable {
    var placedOrders: [Order] = []
    var cancelledIds: [String] = []
    var placeError: Error?
    /// Throw on exactly this 1-based placement attempt (nil = never).
    var placeFailureAtAttempt: Int?
    /// Throw from cancelOrder (compensation-failure path).
    var cancelError: Error?
    var slotToReturn: PickupSlot?
    private var placeAttempts = 0

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

    func backendCartId(forOutlet outletId: String) async throws -> String { "cart-\(outletId)" }

    func placeOrder(cartId: String, pickupSlotId: String, paymentMethod: PaymentMethod) async throws -> Order {
        placeAttempts += 1
        if let placeError { throw placeError }
        if placeFailureAtAttempt == placeAttempts {
            throw AppError.message("placement failed")
        }
        let order = makeOrder()
        placedOrders.append(order)
        return order
    }

    func cancelOrder(orderId: String, reason: String) async throws -> Order {
        if let cancelError { throw cancelError }
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
    /// Throw from create on exactly this 1-based attempt (nil = never).
    var createFailureAtAttempt: Int?
    var isOnlinePaymentConfigured = true
    private var createAttempts = 0

    func createRazorpayOrder(orderId: String) async throws -> RazorpayOrderDetails {
        createAttempts += 1
        if createFailureAtAttempt == createAttempts {
            throw AppError.message("create failed")
        }
        return RazorpayOrderDetails(razorpayOrderId: "rzp-order-1", amount: 10500, keyId: "key-test", currency: "INR")
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
    var clearedSections: [String] = []
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

    func setSlot(cartItemId: String, slotId: String?) async throws -> Cart {
        throw AppError.message("unimplemented in fake")
    }

    func clearCart() async throws { clearCount += 1 }
    func clearSection(outletId: String) async throws { clearedSections.append(outletId) }
    func clearLocal() async throws { clearCount += 1 }
    func pushToBackend() async throws { pushCount += 1 }
}

@MainActor
final class FakeSheet: PaymentSheetProvider {
    var result: RazorpaySheetResult = .cancelled
    var abandonCount = 0
    nonisolated init() {}
    func pay(keyId: String, amountPaise: Int, razorpayOrderId: String,
             outletName: String, email: String?) async -> RazorpaySheetResult {
        result
    }
    func abandon() { abandonCount += 1 }
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
    var categorySections: [CategoryOutlet]?
    var categoryError: Error?
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
    func updateFoodDiet(foodId: String, isVeg: Bool) async throws {}
    func getOutletsForCategory(_ categoryId: String, categoryName: String) async throws -> [CategoryOutlet] {
        if let categoryError { throw categoryError }
        return categorySections ?? []
    }
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

// MARK: - Domain fixture builders

nonisolated enum Fixtures {
    static func cartItem(
        id: String = "line-1",
        foodItemId: String = "food-1",
        foodName: String = "Masala Dosa",
        outletId: String = "outlet-1",
        price: Double = 100,
        quantity: Int = 1
    ) -> CartItem {
        CartItem(
            id: id, foodItemId: foodItemId, foodName: foodName,
            foodImageUrl: nil, outletId: outletId, price: price,
            quantity: quantity, selectedCustomizations: [], isVeg: true,
            specialInstructions: nil
        )
    }

    static func cart(
        outletId: String = "outlet-1",
        outletName: String = "Java Green",
        items: [CartItem]? = nil
    ) -> Cart {
        let lines = items ?? [cartItem(outletId: outletId)]
        let subtotal = lines.reduce(0) { $0 + $1.price * Double($1.quantity) }
        let tax = (subtotal * 0.05 * 100).rounded() / 100
        return Cart(
            outletId: outletId, outletName: outletName, items: lines,
            subtotal: subtotal, tax: tax, total: subtotal + tax,
            estimatedPrepMinutes: 10
        )
    }

    static func slot(
        id: String = "slot-1",
        outletId: String = "outlet-1",
        status: SlotStatus = .available
    ) -> PickupSlot {
        PickupSlot(
            id: id, outletId: outletId, startTime: "12:30",
            endTime: "12:40", date: "2026-09-15", capacity: 10,
            bookedCount: 0, status: status
        )
    }
}

// MARK: - Repository factory

/// A `DefaultAppRepository` wired with fakes, plus handles to the fakes for
/// assertions. Prefer this over hand-rolling repositories in new tests.
struct FakeRepositorySet {
    let repository: DefaultAppRepository
    let orders: FakeOrders
    let payments: FakePayments
    let cart: FakeCart
    let sheet: FakeSheet
}

@MainActor
func makeFakeRepositories() -> FakeRepositorySet {
    let orders = FakeOrders()
    let payments = FakePayments()
    let cart = FakeCart()
    let sheet = FakeSheet()
    let repository = DefaultAppRepository(
        outlets: StubOutlets(), food: StubFood(), cart: cart,
        orders: orders, notifications: StubNotifications(),
        payments: payments, admin: StubAdmin()
    )
    return FakeRepositorySet(
        repository: repository, orders: orders,
        payments: payments, cart: cart, sheet: sheet
    )
}
