import XCTest
@testable import Crave_IOS

/// Checkout state-machine tests: payment verification is authoritative, the
/// cart survives until verification, verify-stage failures re-verify the same
/// order (never cancel a possibly-captured order), and placement is gated.
@MainActor
final class CheckoutViewModelTests: XCTestCase {
    private func makeVMAsync(
        orders: FakeOrders? = nil,
        payments: FakePayments? = nil,
        cartRepo: FakeCart? = nil,
        sheet: FakeSheet? = nil
    ) async -> (CheckoutViewModel, FakeOrders, FakePayments, FakeCart, FakeSheet) {
        let set = makeFakeRepositories()
        let resolvedOrders = orders ?? set.orders
        let resolvedPayments = payments ?? set.payments
        let resolvedCart = cartRepo ?? set.cart
        let resolvedSheet = sheet ?? set.sheet
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: StubFood(), cart: resolvedCart,
            orders: resolvedOrders, notifications: StubNotifications(),
            payments: resolvedPayments, admin: StubAdmin()
        )
        let vm = CheckoutViewModel(cart: Fixtures.cart(), repository: repo, sheet: resolvedSheet)
        await vm.selectSlot(outletId: "outlet-1", slot: Fixtures.slot())
        return (vm, resolvedOrders, resolvedPayments, resolvedCart, resolvedSheet)
    }

    func testHappyPathClearsCartOnlyAfterVerification() async {
        let (vm, orders, payments, cartRepo, sheet) = await makeVMAsync()
        sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")

        await vm.placeOrder()

        if case .success = vm.flowState {} else {
            return XCTFail("expected success, got \(vm.flowState)")
        }
        XCTAssertEqual(orders.placedOrders.count, 1)
        XCTAssertEqual(payments.verifyCalls.count, 1)
        XCTAssertEqual(cartRepo.clearedSections, ["outlet-1"], "section cleared exactly once, after verification")
        XCTAssertEqual(cartRepo.pushCount, 1)
    }

    func testVerifyTimeoutRetryReverifiesSameOrderWithoutCancelling() async {
        let (vm, orders, payments, cartRepo, sheet) = await makeVMAsync()
        sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")
        payments.verifyFailuresRemaining = 1 // first verify attempt times out

        await vm.placeOrder()

        if case .error = vm.flowState {} else {
            return XCTFail("expected error after failed verify, got \(vm.flowState)")
        }
        XCTAssertEqual(cartRepo.clearCount, 0, "cart must survive failed verification")
        XCTAssertTrue(orders.cancelledIds.isEmpty)

        await vm.retryAfterError() // must re-verify, not cancel + re-place

        if case .success = vm.flowState {} else {
            return XCTFail("expected success after re-verify, got \(vm.flowState)")
        }
        XCTAssertTrue(orders.cancelledIds.isEmpty, "must not cancel a possibly-captured order")
        XCTAssertEqual(orders.placedOrders.count, 1, "must not place a second order")
        XCTAssertEqual(payments.verifyCalls.count, 2)
        XCTAssertEqual(cartRepo.clearedSections, ["outlet-1"])
    }

    func testCancelledSheetKeepsOrderAndCart() async {
        let (vm, orders, _, cartRepo, sheet) = await makeVMAsync()
        sheet.result = .cancelled

        await vm.placeOrder()

        if case .paymentCancelled = vm.flowState {} else {
            return XCTFail("expected paymentCancelled, got \(vm.flowState)")
        }
        XCTAssertEqual(orders.placedOrders.count, 1)
        XCTAssertEqual(cartRepo.clearCount, 0)
    }

    func testPlacementGatedBySlots() async {
        let repo = makeFakeRepositories().repository
        let vm = CheckoutViewModel(cart: Fixtures.cart(), repository: repo, sheet: FakeSheet())
        // No slot selected in any section → cannot place.
        XCTAssertFalse(vm.canPlaceOrder)
        await vm.selectSlot(outletId: "outlet-1", slot: Fixtures.slot())
        XCTAssertTrue(vm.canPlaceOrder)
    }

    func testMainButtonReverifiesInsteadOfCancellingPaidOrder() async {
        let (vm, orders, payments, _, sheet) = await makeVMAsync()
        sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")
        payments.verifyFailuresRemaining = 1

        await vm.placeOrder() // verify fails → .error with context retained
        if case .error = vm.flowState {} else {
            return XCTFail("expected error, got \(vm.flowState)")
        }

        await vm.placeOrder() // main button: must re-verify, not cancel + re-place

        if case .success = vm.flowState {} else {
            return XCTFail("expected success, got \(vm.flowState)")
        }
        XCTAssertTrue(orders.cancelledIds.isEmpty, "main button must never cancel a possibly-captured order")
        XCTAssertEqual(orders.placedOrders.count, 1)
        XCTAssertEqual(payments.verifyCalls.count, 2)
    }

    func testMultiOutletSequentialCheckout() async {
        let set = makeFakeRepositories()
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: StubFood(), cart: set.cart,
            orders: set.orders, notifications: StubNotifications(),
            payments: set.payments, admin: StubAdmin()
        )
        var cart = Fixtures.cart()
        cart.items.append(Fixtures.cartItem(id: "line-2", foodItemId: "food-9", foodName: "Burger", outletId: "outlet-2"))
        let t = CartMath.totals(for: cart.items)
        cart.subtotal = t.subtotal
        cart.tax = t.tax
        cart.total = t.total
        XCTAssertEqual(cart.sections.count, 2, "fixture must span two outlets")
        let vm = CheckoutViewModel(cart: cart, repository: repo, sheet: set.sheet)
        set.sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")
        await vm.selectSlot(outletId: "outlet-1", slot: Fixtures.slot())
        await vm.selectSlot(outletId: "outlet-2", slot: Fixtures.slot(id: "slot-2", outletId: "outlet-2"))

        await vm.placeOrder()

        if case .success = vm.flowState {} else {
            return XCTFail("expected success, got \(vm.flowState)")
        }
        XCTAssertEqual(vm.completedOrders.count, 2, "both sections verified")
        XCTAssertEqual(set.orders.placedOrders.count, 2)
        XCTAssertEqual(set.payments.verifyCalls.count, 2, "one verification per section")
        XCTAssertTrue(ordersWerePlacedForBothOutlets(set.orders))
        // Fake orders share one outlet id, so assert per-section clearing by count.
        XCTAssertEqual(set.cart.clearedSections.count, 2)
    }

    private func ordersWerePlacedForBothOutlets(_ orders: FakeOrders) -> Bool {
        orders.placedOrders.count == 2
    }

    private func makeTwoOutletVM(
        orders: FakeOrders = FakeOrders(),
        payments: FakePayments = FakePayments(),
        cartRepo: FakeCart = FakeCart(),
        sheet: FakeSheet = FakeSheet()
    ) async -> (CheckoutViewModel, FakeOrders, FakePayments, FakeCart, FakeSheet) {
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: StubFood(), cart: cartRepo,
            orders: orders, notifications: StubNotifications(),
            payments: payments, admin: StubAdmin()
        )
        var cart = Fixtures.cart()
        cart.items.append(Fixtures.cartItem(id: "line-2", foodItemId: "food-9", foodName: "Burger", outletId: "outlet-2"))
        let t = CartMath.totals(for: cart.items)
        cart.subtotal = t.subtotal
        cart.tax = t.tax
        cart.total = t.total
        let vm = CheckoutViewModel(cart: cart, repository: repo, sheet: sheet)
        await vm.selectSlot(outletId: "outlet-1", slot: Fixtures.slot())
        await vm.selectSlot(outletId: "outlet-2", slot: Fixtures.slot(id: "slot-2", outletId: "outlet-2"))
        return (vm, orders, payments, cartRepo, sheet)
    }

    func testSecondSectionPlacementFailureKeepsVerifiedSection() async {
        let orders = FakeOrders()
        orders.placeFailureAtAttempt = 2 // first section verifies, second fails to place
        let (vm, _, _, cartRepo, sheet) = await makeTwoOutletVM(orders: orders)
        sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")

        await vm.placeOrder()

        if case .error = vm.flowState {} else {
            return XCTFail("expected error, got \(vm.flowState)")
        }
        // Section 1 verified (cleared); section 2 never placed so there is
        // nothing unpaid to compensate.
        XCTAssertTrue(orders.cancelledIds.isEmpty)
        XCTAssertEqual(cartRepo.clearedSections, ["outlet-1"])
        XCTAssertEqual(vm.completedOrders.count, 1)
        if case .error(let message) = vm.flowState {
            XCTAssertFalse(message.contains("contact support"), "no orphans, no support copy: \(message)")
        }
    }

    func testCreateFailureCompensatesPlacedOrder() async {
        let orders = FakeOrders()
        let payments = FakePayments()
        payments.createFailureAtAttempt = 1 // create fails before any sheet
        let (vm, _, _, _, sheet) = await makeTwoOutletVM(orders: orders, payments: payments)
        sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")

        await vm.placeOrder()

        if case .error = vm.flowState {} else {
            return XCTFail("expected error, got \(vm.flowState)")
        }
        // Pre-payment failure: the placed order is safe to cancel immediately.
        XCTAssertEqual(orders.cancelledIds.count, 1)
        if case .error(let message) = vm.flowState {
            XCTAssertFalse(message.contains("contact support"), "compensated, no support copy: \(message)")
        }
    }

    func testCompensationFailureSurfacesOrderNumbers() async {
        let orders = FakeOrders()
        let payments = FakePayments()
        payments.createFailureAtAttempt = 1 // pre-payment: safe to compensate…
        orders.cancelError = AppError.message("cancel RPC down") // …but compensation itself fails
        let (vm, _, _, _, sheet) = await makeTwoOutletVM(orders: orders, payments: payments)
        sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")

        await vm.placeOrder()

        if case .error(let message) = vm.flowState {
            XCTAssertTrue(message.contains("GAG-TEST-1"), "orphan order number must surface: \(message)")
            XCTAssertTrue(message.contains("contact support"), "must direct to support: \(message)")
            XCTAssertTrue(message.contains("create failed"), "original error must not be masked: \(message)")
        } else {
            return XCTFail("expected error, got \(vm.flowState)")
        }
    }

    func testSelectSlotPersistsBestEffort() async {
        // FakeCart.setSlot always throws: selection must still record (placement
        // reads the VM dict, never line slotIds), with no error state change.
        let (vm, _, _, _, _) = await makeVMAsync()
        await vm.selectSlot(outletId: "outlet-1", slot: Fixtures.slot())
        XCTAssertEqual(vm.sections.first?.selectedSlot?.id, "slot-1")
        XCTAssertTrue(vm.canPlaceOrder)
    }

    func testCancelAwaitingPaymentAbandonsHungSheet() async {
        @MainActor
        final class HungSheet: PaymentSheetProvider {
            private(set) var abandoned = false
            func pay(keyId: String, amountPaise: Int, razorpayOrderId: String,
                     outletName: String, email: String?) async -> RazorpaySheetResult {
                // Never resolves until abandoned (killed native sheet).
                while !abandoned { try? await Task.sleep(nanoseconds: 10_000_000) }
                return .cancelled
            }
            func abandon() { abandoned = true }
        }
        let orders = FakeOrders()
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: StubFood(), cart: FakeCart(),
            orders: orders, notifications: StubNotifications(),
            payments: FakePayments(), admin: StubAdmin()
        )
        let cart = Cart(outletId: "outlet-1", outletName: "Java Green",
                        items: [CartItem(id: "l1", foodItemId: "f1", foodName: "Dosa",
                                         foodImageUrl: nil, outletId: "outlet-1", price: 100,
                                         quantity: 1, selectedCustomizations: [], isVeg: true,
                                         specialInstructions: nil)],
                        subtotal: 100, tax: 5, total: 105, estimatedPrepMinutes: 10)
        let hungVM = CheckoutViewModel(cart: cart, repository: repo, sheet: HungSheet())
        await hungVM.selectSlot(outletId: "outlet-1", slot: Fixtures.slot())
        let placing = Task { await hungVM.placeOrder() }
        // Wait until the VM reaches awaitingPayment, then cancel.
        for _ in 0..<200 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if case .awaitingPayment = hungVM.flowState { break }
        }
        if case .awaitingPayment = hungVM.flowState {} else {
            placing.cancel()
            return XCTFail("never reached awaitingPayment, got \(hungVM.flowState)")
        }
        hungVM.cancelAwaitingPayment()
        await placing.value
        if case .paymentCancelled = hungVM.flowState {} else {
            return XCTFail("expected paymentCancelled, got \(hungVM.flowState)")
        }
        XCTAssertTrue(orders.cancelledIds.isEmpty)
    }
}
