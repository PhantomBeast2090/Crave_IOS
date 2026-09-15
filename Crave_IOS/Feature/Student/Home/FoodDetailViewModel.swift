import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class FoodDetailViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(FoodItem)
        case error(message: String)
    }
    
    private(set) var state: State = .idle
    private let repository: AppRepository
    let foodId: String
    
    init(foodId: String, repository: AppRepository) {
        self.foodId = foodId
        self.repository = repository
    }
    
    func load() async {
        guard case .idle = state else { return }
        state = .loading
        
        do {
            let item = try await repository.food.getFoodById(foodId)
            state = .loaded(item)
        } catch is CancellationError {
            // Task was cancelled (e.g. view re-rendered mid-load).
            // Reset so a retry can run; never surface this as an error.
            state = .idle
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
    
    func refresh() async {
        state = .idle
        await load()
    }
    
    func toggleFavorite() async {
        guard case .loaded(var item) = state else { return }
        do {
            let newStatus = try await repository.food.toggleFavorite(foodItemId: item.id)
            item.isFavorite = newStatus
            state = .loaded(item)
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }

    // MARK: - Customization + cart
    //
    // Pricing, validation, and conflict handling live here (not in the View)
    // so they are unit-testable. Mirrors Android FoodDetailViewModel.

    var quantity = 1
    /// variantId -> selected options (multi-select supported via maxSelections).
    var selectedOptions: [String: [CustomizationOption]] = [:]
    var showAddedToCart = false
    var addError: String?
    var isAdding = false
    var pendingConflictAdd: PendingCartAdd?
    var navigateToCart = false
    private var toastTask: Task<Void, Never>?

    func selected(for variantId: String) -> [CustomizationOption] {
        selectedOptions[variantId] ?? []
    }

    func toggleOption(variant: FoodCustomization, option: CustomizationOption) {
        var current = selectedOptions[variant.id] ?? []
        if let index = current.firstIndex(where: { $0.id == option.id }) {
            current.remove(at: index)
        } else if variant.maxSelections <= 1 {
            current = [option]
        } else if current.count < variant.maxSelections {
            current.append(option)
        } else {
            return // cap reached — extra taps are ignored (Android parity)
        }
        if current.isEmpty {
            selectedOptions.removeValue(forKey: variant.id)
        } else {
            selectedOptions[variant.id] = current
        }
    }

    func canAddToCart(_ item: FoodItem) -> Bool {
        guard item.isAvailable else { return false }
        return missingRequiredNames(item).isEmpty
    }

    func missingRequiredNames(_ item: FoodItem) -> [String] {
        item.customizations
            .filter { $0.isRequired && (selectedOptions[$0.id] ?? []).isEmpty }
            .map { $0.name }
    }

    func computedPrice(_ item: FoodItem) -> Double {
        let extras = selectedOptions.values.flatMap { $0 }.reduce(0) { $0 + $1.extraPrice }
        return item.price + extras
    }

    func selectedCustomizations(_ item: FoodItem) -> [SelectedCustomization] {
        item.customizations.flatMap { variant in
            (selectedOptions[variant.id] ?? []).map { option in
                SelectedCustomization(
                    customizationId: variant.id,
                    customizationName: variant.name,
                    optionId: option.id,
                    optionName: option.name,
                    extraPrice: option.extraPrice
                )
            }
        }
    }

    func addToCart(_ item: FoodItem) {
        guard canAddToCart(item), !isAdding else { return }
        isAdding = true
        addError = nil
        Task { [weak self] in
            guard let self else { return }
            defer { self.isAdding = false }
            do {
                _ = try await self.repository.cart.addItem(
                    foodItem: item,
                    outletName: item.outletName,
                    quantity: self.quantity,
                    customizations: self.selectedCustomizations(item),
                    specialInstructions: nil
                )
                self.schedulePostAdd()
            } catch let cartError as CartError {
                if case .outletConflict = cartError {
                    self.pendingConflictAdd = PendingCartAdd(
                        foodItem: item,
                        outletName: item.outletName,
                        quantity: self.quantity,
                        customizations: self.selectedCustomizations(item),
                        specialInstructions: nil
                    )
                } else {
                    self.addError = cartError.localizedDescription
                }
            } catch is CancellationError {
            } catch {
                self.addError = error.localizedDescription
            }
        }
    }

    func confirmConflictAdd() async {
        guard let pending = pendingConflictAdd else { return }
        pendingConflictAdd = nil
        do {
            try await repository.cart.clearCart()
            _ = try await repository.cart.addItem(
                foodItem: pending.foodItem,
                outletName: pending.outletName,
                quantity: pending.quantity,
                customizations: pending.customizations,
                specialInstructions: pending.specialInstructions
            )
            // Same post-add behavior as the direct path: toast, then Cart.
            schedulePostAdd()
        } catch is CancellationError {
        } catch {
            addError = error.localizedDescription
        }
    }

    func dismissConflict() {
        pendingConflictAdd = nil
    }

    /// Cancel a pending toast→Cart navigation (view disappeared). Prevents a
    /// surprise push to Cart after the user already navigated away.
    func cancelPendingNavigation() {
        toastTask?.cancel()
        toastTask = nil
        showAddedToCart = false
    }

    private func schedulePostAdd() {
        toastTask?.cancel()
        withAnimation { showAddedToCart = true }
        toastTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return // cancelled: view went away, stay put
            }
            guard let self else { return }
            withAnimation { self.showAddedToCart = false }
            self.navigateToCart = true
        }
    }
}
