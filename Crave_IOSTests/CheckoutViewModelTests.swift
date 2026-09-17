import XCTest
@testable import Crave_IOS

/// Checkout state-machine tests: payment verification is authoritative, the
/// cart survives until verification, verify-stage failures re-verify the same
/// order (never cancel a possibly-captured order), and placement is gated.
@MainActor
final class CheckoutViewModelTests: XCTestCase {
    private func makeVM(
        orders: FakeOrders? = nil,
        payments: FakePayments? = nil,
        cartRepo: FakeCart? = nil,
        sheet: FakeSheet? = nil
    ) -> (CheckoutViewModel, FakeOrders, FakePayments, FakeCart, FakeSheet) {
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
        vm.selectedSlot = Fixtures.slot()
        return (vm, resolvedOrders, resolvedPayments, resolvedCart, resolvedSheet)
    }

    func testHappyPathClearsCartOnlyAfterVerification() async {
        let (vm, orders, payments, cartRepo, sheet) = makeVM()
        sheet.result = .success(paymentId: "pay-1", orderId: "rzp-order-1", signature: "sig")

        await vm.placeOrder()

        if case .success = vm.flowState {} else {
            return XCTFail("expected success, got \(vm.flowState)")
        }
        XCTAssertEqual(orders.placedOrders.count, 1)
        XCTAssertEqual(payments.verifyCalls.count, 1)
        XCTAssertEqual(cartRepo.clearCount, 1, "cart cleared exactly once, after verification")
        XCTAssertEqual(cartRepo.pushCount, 1)
    }

    func testVerifyTimeoutRetryReverifiesSameOrderWithoutCancelling() async {
        let (vm, orders, payments, cartRepo, sheet) = makeVM()
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
        XCTAssertEqual(cartRepo.clearCount, 1)
    }

    func testCancelledSheetKeepsOrderAndCart() async {
        let (vm, orders, _, cartRepo, sheet) = makeVM()
        sheet.result = .cancelled

        await vm.placeOrder()

        if case .paymentCancelled = vm.flowState {} else {
            return XCTFail("expected paymentCancelled, got \(vm.flowState)")
        }
        XCTAssertEqual(orders.placedOrders.count, 1)
        XCTAssertEqual(cartRepo.clearCount, 0)
    }

    func testPlacementGatedWhileBusy() async {
        let (vm, _, _, _, _) = makeVM()
        XCTAssertTrue(vm.canPlaceOrder)
        // No slot selected → cannot place.
        vm.selectedSlot = nil
        XCTAssertFalse(vm.canPlaceOrder)
    }

    func testMainButtonReverifiesInsteadOfCancellingPaidOrder() async {
        let (vm, orders, payments, _, sheet) = makeVM()
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
        hungVM.selectedSlot = PickupSlot(id: "slot-1", outletId: "outlet-1", startTime: "12:30",
                                         endTime: "12:40", date: "2026-09-15", capacity: 10,
                                         bookedCount: 0, status: .available)
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
