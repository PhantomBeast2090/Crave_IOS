import Foundation
import Observation

/// Shared quick-add behavior for every dish list (outlet menu, search,
/// favorites) — mirrors Android's card `onAddToCart` + "Different Outlet"
/// dialog + snackbar.
///
/// Rules (per product decision):
/// - Dish with required variants → `detailItem` (caller navigates to the
///   detail screen so the user picks required options).
/// - Unavailable dish → quick-add control is disabled; no-op here.
/// - Otherwise add base item × 1 → toast; outlet conflict → `conflictItem`
///   for the caller's confirmation dialog.
@MainActor
@Observable
final class QuickAddHelper {
    /// Set for a transient success toast; nils itself out automatically.
    private(set) var toastMessage: String?
    /// Set when a single-outlet conflict needs user confirmation.
    var conflictItem: FoodItem?
    /// Set when the dish requires detail-screen customization first.
    var detailItem: FoodItem?
    private(set) var errorMessage: String?

    private let repository: CartRepository
    private var toastTask: Task<Void, Never>?

    init(repository: CartRepository) {
        self.repository = repository
    }

    func quickAdd(_ item: FoodItem) {
        errorMessage = nil
        guard item.isAvailable else { return }
        if item.customizations.contains(where: { $0.isRequired }) {
            detailItem = item
            return
        }
        Task {
            do {
                _ = try await repository.addItem(
                    foodItem: item,
                    outletName: item.outletName,
                    quantity: 1,
                    customizations: [],
                    specialInstructions: nil
                )
                showToast("Added \(item.name) to cart")
            } catch let cartError as CartError {
                if case .outletConflict = cartError {
                    conflictItem = item
                } else {
                    errorMessage = cartError.localizedDescription
                }
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// "Clear & Add" — clears the cart, then adds the conflicted item.
    func confirmConflictAdd() {
        guard let item = conflictItem else { return }
        conflictItem = nil
        errorMessage = nil
        Task {
            do {
                try await repository.clearCart()
                _ = try await repository.addItem(
                    foodItem: item,
                    outletName: item.outletName,
                    quantity: 1,
                    customizations: [],
                    specialInstructions: nil
                )
                showToast("Added \(item.name) to cart")
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func dismissConflict() {
        conflictItem = nil
    }

    func consumeDetailItem() -> FoodItem? {
        defer { detailItem = nil }
        return detailItem
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                toastMessage = nil
            }
        }
    }
}
