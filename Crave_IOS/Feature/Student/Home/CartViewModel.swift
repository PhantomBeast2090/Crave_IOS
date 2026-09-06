import Foundation
import Observation

/// Add-to-cart request held while the "Different Outlet" dialog is shown.
struct PendingCartAdd: Sendable, Equatable {
    let foodItem: FoodItem
    let outletName: String
    let quantity: Int
    let customizations: [SelectedCustomization]
    let specialInstructions: String?
}

@MainActor
@Observable
final class CartViewModel {
    private(set) var cart: Cart?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Set when `addItem` hits a single-outlet conflict — the UI shows
    /// Android's "Different Outlet / Clear & Add / Keep Cart" dialog.
    var pendingConflict: PendingCartAdd?

    private let repository: CartRepository
    private var observeTask: Task<Void, Never>?

    init(repository: CartRepository) {
        self.repository = repository
    }

    var isEmpty: Bool { cart?.isEmpty ?? true }
    var itemCount: Int { cart?.totalItems ?? 0 }
    var subtotal: Double { cart?.subtotal ?? 0 }
    var tax: Double { cart?.tax ?? 0 }
    var total: Double { cart?.total ?? 0 }

    func start() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.repository.observeCart() {
                self.cart = updated
            }
        }
        Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }
            do {
                try await self.repository.syncFromBackend()
            } catch is CancellationError {
                // Ignore — view went away.
            } catch {
                // Offline on first load is fine; local cart still shows.
                print("⚠️ [CartViewModel] backend sync failed: \(error)")
            }
        }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
    }

    // MARK: - Mutations (single-outlet conflict surfaces via pendingConflict)

    func requestAdd(
        foodItem: FoodItem,
        outletName: String,
        quantity: Int = 1,
        customizations: [SelectedCustomization] = [],
        specialInstructions: String? = nil
    ) async -> Bool {
        errorMessage = nil
        do {
            _ = try await repository.addItem(
                foodItem: foodItem,
                outletName: outletName,
                quantity: quantity,
                customizations: customizations,
                specialInstructions: specialInstructions
            )
            return true
        } catch let cartError as CartError {
            if case .outletConflict = cartError {
                pendingConflict = PendingCartAdd(
                    foodItem: foodItem,
                    outletName: outletName,
                    quantity: quantity,
                    customizations: customizations,
                    specialInstructions: specialInstructions
                )
                return false
            }
            errorMessage = cartError.localizedDescription
            return false
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// "Clear & Add" — clears the cart, then adds the pending item.
    func confirmConflictAdd() async -> Bool {
        guard let pending = pendingConflict else { return false }
        pendingConflict = nil
        errorMessage = nil
        do {
            try await repository.clearCart()
            _ = try await repository.addItem(
                foodItem: pending.foodItem,
                outletName: pending.outletName,
                quantity: pending.quantity,
                customizations: pending.customizations,
                specialInstructions: pending.specialInstructions
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func dismissConflict() {
        pendingConflict = nil
    }

    func updateQuantity(_ item: CartItem, quantity: Int) async {
        errorMessage = nil
        do {
            _ = try await repository.updateQuantity(cartItemId: item.id, quantity: quantity)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeItem(_ item: CartItem) async {
        errorMessage = nil
        do {
            _ = try await repository.removeItem(cartItemId: item.id)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCart() async {
        errorMessage = nil
        do {
            try await repository.clearCart()
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
