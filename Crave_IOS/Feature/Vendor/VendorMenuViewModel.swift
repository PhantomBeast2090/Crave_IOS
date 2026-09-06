import Foundation
import Observation

@MainActor
@Observable
final class VendorMenuViewModel {
    enum State {
        case idle
        case loading
        case loaded([FoodItem])
        case error(message: String)
    }

    private(set) var state: State = .idle
    private(set) var updatingItemId: String?
    private(set) var actionError: String?

    private let repository: FoodRepository

    init(repository: FoodRepository) {
        self.repository = repository
    }

    var items: [FoodItem] {
        if case .loaded(let items) = state { return items }
        return []
    }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        do {
            state = .loaded(try await repository.getVendorFoodItems())
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            if items.isEmpty {
                state = .error(message: error.localizedDescription)
            } else {
                actionError = error.localizedDescription
            }
        }
    }

    func toggleAvailability(_ item: FoodItem) async {
        guard updatingItemId == nil else { return }
        updatingItemId = item.id
        actionError = nil
        defer { updatingItemId = nil }
        do {
            try await repository.updateFoodAvailability(foodId: item.id, isAvailable: !item.isAvailable)
            await fetch()
        } catch is CancellationError {
        } catch {
            actionError = error.localizedDescription
        }
    }

    func updatePrice(_ item: FoodItem, price: Double) async -> Bool {
        guard updatingItemId == nil, price > 0 else { return false }
        updatingItemId = item.id
        actionError = nil
        defer { updatingItemId = nil }
        do {
            try await repository.updateFoodPrice(foodId: item.id, price: price)
            await fetch()
            return true
        } catch is CancellationError {
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
}
