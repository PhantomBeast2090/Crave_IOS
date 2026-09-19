import XCTest
@testable import Crave_IOS

/// Category discovery: dedicated results (never Search), outlet grouping,
/// outlet-without-dishes exclusion, and real-data filters.
@MainActor
final class CategoryResultsViewModelTests: XCTestCase {
    private func dish(id: String, name: String, price: Double, isVeg: Bool, outlet: String = "outlet-1") -> FoodItem {
        FoodItem(
            id: id, name: name, description: "", imageUrl: nil, price: price,
            outletId: outlet, outletName: outlet, category: "Biryani",
            isVeg: isVeg, isAvailable: true, prepTimeMinutes: 10, rating: 4.5,
            totalReviews: 5, ingredients: [], customizations: [], tags: [],
            calories: nil, isPopular: false, isRecommended: false
        )
    }

    private func makeVM(sections: [CategoryOutlet]) -> (CategoryResultsViewModel, StubFood) {
        let food = StubFood()
        food.categorySections = sections
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: food, cart: FakeCart(),
            orders: FakeOrders(), notifications: StubNotifications(),
            payments: FakePayments(), admin: StubAdmin()
        )
        let category = FoodCategory(id: "cat-1", name: "Biryani", emoji: "", imageUrl: nil)
        return (CategoryResultsViewModel(category: category, repository: repo), food)
    }

    func testEmptySectionsBecomeEmptyState() async {
        let (vm, _) = makeVM(sections: [])
        await vm.load()
        if case .empty = vm.state {} else {
            return XCTFail("expected empty, got \(vm.state)")
        }
    }

    func testSectionsPreservedWithCounts() async {
        let sections = [
            CategoryOutlet(outletId: "o1", outletName: "Java Green", dishes: [
                dish(id: "d1", name: "Chicken Biryani", price: 140, isVeg: false),
                dish(id: "d2", name: "Veg Biryani", price: 110, isVeg: true),
            ]),
            CategoryOutlet(outletId: "o2", outletName: "Food Court", dishes: [
                dish(id: "d3", name: "Egg Biryani", price: 120, isVeg: false, outlet: "o2"),
            ]),
        ]
        let (vm, _) = makeVM(sections: sections)
        await vm.load()
        XCTAssertEqual(vm.visibleSections.count, 2)
        XCTAssertEqual(vm.dishCount, 3)
        XCTAssertEqual(vm.visibleSections[0].fromPrice, 110)
    }

    func testVegFilterDropsEmptySections() async {
        let sections = [
            CategoryOutlet(outletId: "o1", outletName: "Java Green", dishes: [
                dish(id: "d1", name: "Chicken Biryani", price: 140, isVeg: false),
                dish(id: "d2", name: "Veg Biryani", price: 110, isVeg: true),
            ]),
            CategoryOutlet(outletId: "o2", outletName: "Meat House", dishes: [
                dish(id: "d3", name: "Chicken Biryani", price: 150, isVeg: false, outlet: "o2"),
            ]),
        ]
        let (vm, _) = makeVM(sections: sections)
        await vm.load()
        vm.dietFilter = .veg
        let visible = vm.visibleSections
        XCTAssertEqual(visible.count, 1, "outlet left with no veg dishes must vanish")
        XCTAssertEqual(visible.first?.outletId, "o1")
        XCTAssertEqual(visible.first?.dishes.map(\.id), ["d2"])
    }

    func testNonVegFilter() async {
        let sections = [
            CategoryOutlet(outletId: "o1", outletName: "Java Green", dishes: [
                dish(id: "d1", name: "Chicken Biryani", price: 140, isVeg: false),
                dish(id: "d2", name: "Veg Biryani", price: 110, isVeg: true),
            ]),
        ]
        let (vm, _) = makeVM(sections: sections)
        await vm.load()
        vm.dietFilter = .nonVeg
        XCTAssertEqual(vm.visibleSections.first?.dishes.map(\.id), ["d1"])
    }

    func testUnder100Filter() async {
        let sections = [
            CategoryOutlet(outletId: "o1", outletName: "Java Green", dishes: [
                dish(id: "d1", name: "Chicken Biryani", price: 140, isVeg: false),
                dish(id: "d2", name: "Veg Biryani", price: 90, isVeg: true),
            ]),
        ]
        let (vm, _) = makeVM(sections: sections)
        await vm.load()
        vm.under100Only = true
        XCTAssertEqual(vm.visibleSections.first?.dishes.map(\.id), ["d2"])
    }

    func testErrorState() async {
        let food = StubFood()
        food.categoryError = AppError.message("offline")
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: food, cart: FakeCart(),
            orders: FakeOrders(), notifications: StubNotifications(),
            payments: FakePayments(), admin: StubAdmin()
        )
        let vm = CategoryResultsViewModel(
            category: FoodCategory(id: "c", name: "Biryani", emoji: "", imageUrl: nil),
            repository: repo
        )
        await vm.load()
        if case .error = vm.state {} else {
            return XCTFail("expected error, got \(vm.state)")
        }
    }
}

/// Dietary mapping: veg/non-veg preserved through domain and entities.
final class DietaryMappingTests: XCTestCase {
    func testCartEntityPreservesDiet() {
        for isVeg in [true, false] {
            let entity = CartItemEntity(
                id: "l1", foodItemId: "f1", foodName: "Dosa", foodImageUrl: nil,
                outletId: "o1", outletName: "Java", price: 60, quantity: 1,
                isVeg: isVeg
            )
            XCTAssertEqual(entity.toCartItem().isVeg, isVeg)
        }
    }
}
