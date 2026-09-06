import XCTest
@testable import Crave_IOS

/// Cart pricing + merge-key math. The server recomputes authoritatively in
/// `place_order`; these tests pin the client-side displaymath to the same
/// contract (5% GST, extras × quantity, stable dedup keys).
final class CartMathTests: XCTestCase {
    private func customization(
        id: String = "v1",
        name: String = "Size",
        optionId: String = "o1",
        optionName: String = "Large",
        extra: Double = 0
    ) -> SelectedCustomization {
        SelectedCustomization(customizationId: id, customizationName: name,
                              optionId: optionId, optionName: optionName, extraPrice: extra)
    }

    private func item(price: Double, qty: Int, extras: [SelectedCustomization] = []) -> CartItem {
        CartItem(id: UUID().uuidString, foodItemId: "f1", foodName: "Biryani",
                 foodImageUrl: nil, outletId: "o1", price: price, quantity: qty,
                 selectedCustomizations: extras, isVeg: true, specialInstructions: nil)
    }

    func testItemTotalIncludesExtrasTimesQuantity() {
        let item = item(price: 100, qty: 2, extras: [customization(extra: 20), customization(optionId: "o2", extra: 10)])
        XCTAssertEqual(item.itemTotal, 260, accuracy: 0.001)
    }

    func testTotalsApplyFivePercentTax() {
        let items = [item(price: 100, qty: 1), item(price: 50, qty: 2)]
        let t = CartMath.totals(for: items)
        XCTAssertEqual(t.subtotal, 200, accuracy: 0.001)
        XCTAssertEqual(t.tax, 10, accuracy: 0.001)
        XCTAssertEqual(t.total, 210, accuracy: 0.001)
        XCTAssertEqual(CartMath.taxRate, 0.05, accuracy: 0.0001)
    }

    func testEmptyCartTotalsZero() {
        let t = CartMath.totals(for: [])
        XCTAssertEqual(t.subtotal, 0)
        XCTAssertEqual(t.tax, 0)
        XCTAssertEqual(t.total, 0)
    }

    func testCustomizationKeyIgnoresOrder() {
        let a = [customization(optionId: "o2"), customization(optionId: "o1")]
        let b = [customization(optionId: "o1"), customization(optionId: "o2")]
        XCTAssertEqual(CartMath.customizationKey(a), CartMath.customizationKey(b))
    }

    func testCustomizationKeyDistinguishesOptions() {
        let a = [customization(optionId: "o1")]
        let b = [customization(optionId: "o2")]
        XCTAssertNotEqual(CartMath.customizationKey(a), CartMath.customizationKey(b))
        XCTAssertEqual(CartMath.customizationKey([]), "")
    }

    func testSnapshotCarriesOutletAndPrepEstimate() {
        let cart = CartMath.snapshot(outletId: "o1", outletName: "Main Canteen",
                                     items: [item(price: 10, qty: 1), item(price: 20, qty: 1)])
        XCTAssertEqual(cart.outletId, "o1")
        XCTAssertEqual(cart.outletName, "Main Canteen")
        XCTAssertEqual(cart.estimatedPrepMinutes, 10) // 5 min per line, Android parity
        XCTAssertEqual(cart.totalItems, 2)
        XCTAssertFalse(cart.isEmpty)
    }

    func testMaxQuantityContract() {
        XCTAssertEqual(CartMath.maxQuantity, 10) // Android MAX_CART_QUANTITY
    }
}
