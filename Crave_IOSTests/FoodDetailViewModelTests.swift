import XCTest
@testable import Crave_IOS

/// Food detail customization/pricing logic. These behaviours lived in the
/// View until the Phase 2 refactor moved them into FoodDetailViewModel.
@MainActor
final class FoodDetailViewModelTests: XCTestCase {
    private func makeItem(required: Bool = true) -> FoodItem {
        let size = FoodCustomization(
            id: "size", name: "Size",
            options: [
                CustomizationOption(id: "s", name: "Regular", extraPrice: 0),
                CustomizationOption(id: "m", name: "Large", extraPrice: 30),
            ],
            isRequired: required, maxSelections: 1
        )
        let addons = FoodCustomization(
            id: "addons", name: "Add-ons",
            options: [
                CustomizationOption(id: "cheese", name: "Cheese", extraPrice: 20),
                CustomizationOption(id: "paneer", name: "Paneer", extraPrice: 40),
                CustomizationOption(id: "corn", name: "Corn", extraPrice: 15),
            ],
            isRequired: false, maxSelections: 2
        )
        return FoodItem(
            id: "food-1", name: "Masala Dosa", description: "Crisp",
            imageUrl: nil, price: 100, outletId: "outlet-1",
            outletName: "Java Green", category: "Meals", isVeg: true,
            isAvailable: true, prepTimeMinutes: 10, rating: 4.5,
            totalReviews: 10, ingredients: [], customizations: [size, addons],
            tags: [], calories: nil, isPopular: false, isRecommended: false
        )
    }

    private func makeVM() -> FoodDetailViewModel {
        let repo = DefaultAppRepository(
            outlets: StubOutlets(), food: StubFood(), cart: FakeCart(),
            orders: FakeOrders(), notifications: StubNotifications(),
            payments: FakePayments(), admin: StubAdmin()
        )
        return FoodDetailViewModel(foodId: "food-1", repository: repo)
    }

    func testRequiredGroupGatesAddToCart() {
        let vm = makeVM()
        let item = makeItem()
        XCTAssertFalse(vm.canAddToCart(item))
        XCTAssertEqual(vm.missingRequiredNames(item), ["Size"])
        vm.toggleOption(variant: item.customizations[0], option: item.customizations[0].options[0])
        XCTAssertTrue(vm.canAddToCart(item))
        XCTAssertTrue(vm.missingRequiredNames(item).isEmpty)
    }

    func testSingleSelectReplaces() {
        let vm = makeVM()
        let item = makeItem()
        let size = item.customizations[0]
        vm.toggleOption(variant: size, option: size.options[0])
        vm.toggleOption(variant: size, option: size.options[1])
        XCTAssertEqual(vm.selected(for: "size").map(\.id), ["m"])
        XCTAssertEqual(vm.computedPrice(item), 130, accuracy: 0.001)
    }

    func testMultiSelectCap() {
        let vm = makeVM()
        let item = makeItem()
        let addons = item.customizations[1]
        vm.toggleOption(variant: addons, option: addons.options[0])
        vm.toggleOption(variant: addons, option: addons.options[1])
        vm.toggleOption(variant: addons, option: addons.options[2]) // over cap: ignored
        XCTAssertEqual(vm.selected(for: "addons").map(\.id), ["cheese", "paneer"])
        // Deselect by toggling again.
        vm.toggleOption(variant: addons, option: addons.options[0])
        XCTAssertEqual(vm.selected(for: "addons").map(\.id), ["paneer"])
    }

    func testUnavailableItemCannotBeAdded() {
        let vm = makeVM()
        var unavailable = makeItem(required: false)
        unavailable = FoodItem(
            id: unavailable.id, name: unavailable.name, description: unavailable.description,
            imageUrl: nil, price: unavailable.price, outletId: unavailable.outletId,
            outletName: unavailable.outletName, category: unavailable.category,
            isVeg: true, isAvailable: false, prepTimeMinutes: 10, rating: 4.5,
            totalReviews: 10, ingredients: [], customizations: [],
            tags: [], calories: nil, isPopular: false, isRecommended: false
        )
        XCTAssertFalse(vm.canAddToCart(unavailable))
    }

    func testSelectedCustomizationsMapping() {
        let vm = makeVM()
        let item = makeItem()
        vm.toggleOption(variant: item.customizations[0], option: item.customizations[0].options[1])
        let mapped = vm.selectedCustomizations(item)
        XCTAssertEqual(mapped.count, 1)
        XCTAssertEqual(mapped[0].customizationId, "size")
        XCTAssertEqual(mapped[0].optionId, "m")
        XCTAssertEqual(mapped[0].extraPrice, 30, accuracy: 0.001)
    }
}
