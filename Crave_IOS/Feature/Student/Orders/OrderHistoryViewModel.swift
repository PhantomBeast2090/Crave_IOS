import Foundation
import Observation

@MainActor
@Observable
final class OrderHistoryViewModel {
    enum State {
        case idle
        case loading
        case loaded([Order])
        case error(message: String)
    }

    private(set) var state: State = .idle
    private let repository: OrderRepository
    private var observeTask: Task<Void, Never>?

    init(repository: OrderRepository) {
        self.repository = repository
    }

    var activeOrders: [Order] {
        if case .loaded(let orders) = state { return orders.filter { $0.status.isActive } }
        return []
    }

    var pastOrders: [Order] {
        if case .loaded(let orders) = state { return orders.filter { $0.status.isTerminal } }
        return []
    }

    var isEmpty: Bool { activeOrders.isEmpty && pastOrders.isEmpty }

    func start() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await orders in self.repository.observeOrders() {
                // Don't clobber an explicit error with a stale empty cache.
                if case .error = self.state, orders.isEmpty { continue }
                self.state = .loaded(orders)
            }
        }
        Task { [weak self] in await self?.refresh() }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
    }

    func refresh() async {
        if case .loading = state { return }
        let hadData: Bool = {
            if case .loaded(let orders) = state { return !orders.isEmpty }
            return false
        }()
        if !hadData { state = .loading }
        do {
            let orders = try await repository.refreshOrders()
            state = .loaded(orders)
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            if !hadData {
                state = .error(message: error.localizedDescription)
            }
        }
    }
}
