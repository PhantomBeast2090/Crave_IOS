import XCTest
@testable import Crave_IOS

/// Multi-outlet cart: grouping, per-outlet totals, and slot matching.
final class MultiOutletTests: XCTestCase {
    private func line(_ id: String, outlet: String, price: Double = 100) -> CartItem {
        Fixtures.cartItem(id: id, foodItemId: "f-\(id)", foodName: id, outletId: outlet, price: price)
    }

    func testGroupedSections() {
        let items = [line("a", outlet: "o1"), line("b", outlet: "o2", price: 50), line("c", outlet: "o1", price: 25)]
        let sections = CartMath.groupedSections(items: items)
        XCTAssertEqual(sections.map(\.outletId), ["o1", "o2"])
        XCTAssertEqual(sections[0].items.map(\.id), ["a", "c"])
        XCTAssertEqual(sections[0].subtotal, 125, accuracy: 0.001)
        XCTAssertEqual(sections[1].subtotal, 50, accuracy: 0.001)
        // Grand total equals the sum of sections.
        let grand = sections.reduce(0) { $0 + $1.total }
        let t = CartMath.totals(for: items)
        XCTAssertEqual(grand, t.total, accuracy: 0.001)
    }

    func testSingleOutletIsOneSection() {
        let sections = CartMath.groupedSections(items: [line("a", outlet: "o1")])
        XCTAssertEqual(sections.count, 1)
    }

    func testCartSectionsDerived() {
        var cart = Fixtures.cart()
        cart.items.append(Fixtures.cartItem(id: "x", foodItemId: "fx", foodName: "X", outletId: "outlet-2"))
        XCTAssertEqual(cart.sections.count, 2)
        XCTAssertEqual(Set(cart.outletIds), ["outlet-1", "outlet-2"])
    }

    // MARK: - Slot matching

    private func slot(_ id: String, start: String, end: String, selectable: Bool = true) -> PickupSlot {
        PickupSlot(
            id: id, outletId: "o", startTime: start, endTime: end,
            date: "2026-09-15", capacity: 10, bookedCount: 0,
            status: selectable ? .available : .full
        )
    }

    func testCommonWindows() {
        let byOutlet = [
            "a": [slot("a1", start: "12:30", end: "12:45"), slot("a2", start: "13:00", end: "13:15")],
            "b": [slot("b1", start: "12:45", end: "13:00"), slot("b2", start: "13:00", end: "13:15")],
        ]
        let common = SlotMatcher.commonWindows(slotsByOutlet: byOutlet)
        XCTAssertEqual(common, [SlotMatcher.CommonWindow(startTime: "13:00", endTime: "13:15")])
    }

    func testNoCommonWindow() {
        let byOutlet = [
            "a": [slot("a1", start: "12:30", end: "12:45")],
            "b": [slot("b1", start: "13:30", end: "13:45")],
        ]
        XCTAssertTrue(SlotMatcher.commonWindows(slotsByOutlet: byOutlet).isEmpty)
    }

    func testFullSlotsExcluded() {
        let byOutlet = [
            "a": [slot("a1", start: "12:30", end: "12:45")],
            "b": [slot("b1", start: "12:30", end: "12:45", selectable: false)],
        ]
        XCTAssertTrue(SlotMatcher.commonWindows(slotsByOutlet: byOutlet).isEmpty)
    }

    func testSlotIdsForWindow() {
        let window = SlotMatcher.CommonWindow(startTime: "13:00", endTime: "13:15")
        let byOutlet = [
            "a": [slot("a9", start: "13:00", end: "13:15")],
            "b": [slot("b1", start: "12:30", end: "12:45")],
        ]
        let ids = SlotMatcher.slotIds(for: window, in: byOutlet)
        XCTAssertEqual(ids, ["a": "a9"], "outlets without the window must be absent, never force-assigned")
    }

    func testEmptyInput() {
        XCTAssertTrue(SlotMatcher.commonWindows(slotsByOutlet: [:]).isEmpty)
    }
}
