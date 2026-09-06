import Foundation
import Observation

@MainActor
@Observable
final class VendorOrdersViewModel {
    enum State {
        case idle
        case loading
        case loaded([Order])
        case error(message: String)
    }

    private(set) var state: State = .idle
    private let repository: OrderRepository

    init(repository: OrderRepository) {
        self.repository = repository
    }

    var orders: [Order] {
        if case .loaded(let orders) = state { return orders }
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
            state = .loaded(try await repository.getVendorOrders(status: nil))
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            if orders.isEmpty {
                state = .error(message: error.localizedDescription)
            }
        }
    }
}
