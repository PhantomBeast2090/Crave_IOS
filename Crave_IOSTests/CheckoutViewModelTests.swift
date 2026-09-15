import XCTest
@testable import Crave_IOS

/// Checkout state-machine tests: payment verification is authoritative, the
/// cart survives until verification, verify-stage failures re-verify the same
/// order (never cancel a possibly-captured order), and placement is gated.
@MainActor
final class CheckoutViewModelTests: XCTestCase {
    private func makeCart() -> Cart {
        Cart(
            outletId: "outlet-1", outletName: "Java Green",
            items: [CartItem(
                id: "line-1", foodItemId: "food-1", foodName: "Masala Dosa",
                foodImageUrl: nil, outletId: "outlet-1", price: 100,
                quantity: 1, selectedCustomizations: [], isVeg: true,
                specialInstructions: nil
            )],
            subtotal: 100, tax: 5, total: 105, estimatedPrepMinutes: 10
        )
    }

    private func makeSlot() -> PickupSlot {
        PickupSlot(
            id: "slot-1", outletId: "outlet-1", startTime: "12:30",
            endTime: "12:40", date: "2026-09-15", capacity: 10,
            bookedCount: 0, status: .available
        )
    }

    private func makeVM(
        orders: FakeOrders = FakeOrders(),
        payments: FakePayments = FakePayments(),
        cartRepo: FakeCart = FakeCart(),
        sheet: FakeSheet = FakeSheet()
    ) -> (CheckoutViewModel, FakeOrders, FakePayments, FakeCart, FakeSheet) {
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: StubFood(), cart: cartRepo,
            orders: orders, notifications: StubNotifications(),
            payments: payments, admin: StubAdmin()
        )
        let vm = CheckoutViewModel(cart: makeCart(), repository: repo, sheet: sheet)
        vm.selectedSlot = makeSlot()
        return (vm, orders, payments, cartRepo, sheet)
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
}
