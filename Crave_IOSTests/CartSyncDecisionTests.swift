import XCTest
@testable import Crave_IOS

/// Cart sync merge policy (SupabaseCartRepository.resolveSync). Guards the
/// reported "added to cart, cart stays empty" bug: a failed/empty/stale
/// remote fetch must never wipe just-added local lines.
final class CartSyncDecisionTests: XCTestCase {
    private func line(
        id: String = UUID().uuidString,
        outlet: String = "outlet-B",
        food: String = "food-1",
        createdAt: Date = Date()
    ) -> CartItemEntity {
        let e = CartItemEntity(
            id: id, foodItemId: food, foodName: "Dosa", foodImageUrl: nil,
            outletId: outlet, outletName: outlet, price: 60,
            quantity: 1, isVeg: true
        )
        e.createdAt = createdAt
        return e
    }

    private var hourAgo: Date { Date().addingTimeInterval(-3600) }

    func testEmptyLocalAdoptsRemote() {
        let remote = [line(outlet: "outlet-A")]
        switch SupabaseCartRepository.resolveSync(
            local: [], remote: remote, remoteOutlet: "outlet-A", remoteUpdated: Date()
        ) {
        case .adopt(let merged): XCTAssertEqual(merged.count, 1)
        case .keepLocal: XCTFail("empty local must adopt remote")
        }
    }

    func testStaleEmptyRemoteKeepsFreshLocal() {
        // Just-added lines vs a stale residue server row: keep local.
        let local = [line(outlet: "outlet-B", createdAt: Date())]
        switch SupabaseCartRepository.resolveSync(
            local: local, remote: [], remoteOutlet: "outlet-A", remoteUpdated: hourAgo
        ) {
        case .keepLocal: break
        case .adopt: XCTFail("stale empty remote must not wipe fresh local")
        }
    }

    func testFreshEmptyRemoteAdoptsEmpty() {
        // Server cleared after us (e.g. post-payment): adopt the empty cart
        // so paid lines are not resurrected locally.
        let local = [line(outlet: "outlet-B", createdAt: hourAgo)]
        switch SupabaseCartRepository.resolveSync(
            local: local, remote: [], remoteOutlet: "outlet-B", remoteUpdated: Date()
        ) {
        case .adopt(let merged): XCTAssertTrue(merged.isEmpty)
        case .keepLocal: XCTFail("fresh server clear must win")
        }
    }

    func testOutletMismatchFreshLocalWins() {
        let local = [line(outlet: "outlet-B", food: "food-B", createdAt: Date())]
        let remote = [line(outlet: "outlet-A", food: "food-A")]
        switch SupabaseCartRepository.resolveSync(
            local: local, remote: remote, remoteOutlet: "outlet-A", remoteUpdated: hourAgo
        ) {
        case .keepLocal: break
        case .adopt: XCTFail("fresh local must beat stale remote on conflict")
        }
    }

    func testOutletMismatchFreshRemoteWins() {
        let local = [line(outlet: "outlet-B", food: "food-B", createdAt: hourAgo)]
        let remote = [line(outlet: "outlet-A", food: "food-A")]
        switch SupabaseCartRepository.resolveSync(
            local: local, remote: remote, remoteOutlet: "outlet-A", remoteUpdated: Date()
        ) {
        case .adopt(let merged):
            XCTAssertEqual(merged.count, 1)
            XCTAssertEqual(merged.first?.outletId, "outlet-A")
        case .keepLocal: XCTFail("fresh remote must win conflict")
        }
    }

    func testSameOutletMergesWithoutDuplicates() {
        let shared = line(outlet: "outlet-A", food: "food-1", createdAt: hourAgo)
        let localOnly = line(outlet: "outlet-A", food: "food-2")
        switch SupabaseCartRepository.resolveSync(
            local: [shared, localOnly], remote: [shared],
            remoteOutlet: "outlet-A", remoteUpdated: nil
        ) {
        case .adopt(let merged): XCTAssertEqual(merged.count, 2)
        case .keepLocal: XCTFail("same outlet must merge")
        }
    }

    func testUnknownDatesFallBackToServer() {
        let local = [line(outlet: "outlet-B")]
        let remote = [line(outlet: "outlet-A")]
        switch SupabaseCartRepository.resolveSync(
            local: local, remote: remote, remoteOutlet: "outlet-A", remoteUpdated: nil
        ) {
        case .adopt: break
        case .keepLocal: XCTFail("unknown freshness must resolve to server")
        }
    }
}
