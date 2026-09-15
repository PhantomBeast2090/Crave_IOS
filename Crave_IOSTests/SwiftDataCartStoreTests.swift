import SwiftData
import XCTest
@testable import Crave_IOS

/// Regression tests for SwiftDataCartStore.upsert.
///
/// The store previously inserted only when no row with the id existed, so
/// quantity/price edits made through the repository's mutate-then-upsert flow
/// (SupabaseCartRepository add/set-quantity paths) were silently dropped on
/// the SwiftData path and never survived relaunch.
final class SwiftDataCartStoreTests: XCTestCase {
    private func makeStore() throws -> SwiftDataCartStore {
        let container = try ModelContainer(
            for: CartItemEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataCartStore(modelContainer: container)
    }

    private func makeItem(id: String = "line-1", quantity: Int = 1) -> CartItemEntity {
        CartItemEntity(
            id: id,
            foodItemId: "food-1",
            foodName: "Masala Dosa",
            foodImageUrl: nil,
            outletId: "outlet-1",
            outletName: "Java Green",
            price: 60,
            quantity: quantity,
            isVeg: true
        )
    }

    func testUpsertInsertsNewItem() async throws {
        let store = try makeStore()
        try await store.upsert(makeItem())
        let loaded = await store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.quantity, 1)
    }

    func testUpsertPersistsQuantityChangeForExistingId() async throws {
        let store = try makeStore()
        try await store.upsert(makeItem(quantity: 1))

        // Repository flow: mutate the (detached) instance, then upsert.
        let edited = makeItem(quantity: 3)
        try await store.upsert(edited)

        let loaded = await store.loadAll()
        XCTAssertEqual(loaded.count, 1, "upsert must replace, not duplicate")
        XCTAssertEqual(loaded.first?.quantity, 3, "quantity edit must persist")
    }

    func testUpsertDoesNotDuplicateAcrossRepeatedWrites() async throws {
        let store = try makeStore()
        try await store.upsert(makeItem(quantity: 1))
        try await store.upsert(makeItem(quantity: 2))
        try await store.upsert(makeItem(quantity: 3))
        let loaded = await store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.quantity, 3)
    }

    func testDeleteAndClear() async throws {
        let store = try makeStore()
        try await store.upsert(makeItem(id: "a"))
        try await store.upsert(makeItem(id: "b"))
        try await store.delete(id: "a")
        let afterDelete = await store.loadAll()
        XCTAssertEqual(afterDelete.count, 1)
        try await store.clear()
        let afterClear = await store.loadAll()
        XCTAssertTrue(afterClear.isEmpty)
    }
}
