import Foundation
import Observation

@MainActor
@Observable
final class VendorOrderDetailViewModel {
    enum State {
        case idle
        case loading
        case loaded(Order)
        case error(message: String)
    }

    private(set) var state: State = .idle
    private(set) var isActing = false
    private(set) var actionError: String?

    let orderId: String
    private let repository: OrderRepository

    init(orderId: String, repository: OrderRepository) {
        self.orderId = orderId
        self.repository = repository
    }

    var order: Order? {
        if case .loaded(let order) = state { return order }
        return nil
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
            state = .loaded(try await repository.getOrderById(orderId))
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            if order == nil {
                state = .error(message: error.localizedDescription)
            } else {
                actionError = error.localizedDescription
            }
        }
    }

    func accept() async { await act(repository.acceptOrder) }
    func startPreparing() async { await act(repository.startPreparing) }
    func markReady() async { await act(repository.markReady) }

    func reject(reason: String = "Rejected") async {
        await act { [weak self] id in
            guard let self else { throw AppError.message("Cancelled") }
            return try await self.repository.rejectOrder(orderId: id, reason: reason)
        }
    }

    private func act(_ action: (String) async throws -> Order) async {
        guard !isActing else { return }
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            state = .loaded(try await action(orderId))
        } catch is CancellationError {
        } catch {
            actionError = error.localizedDescription
        }
    }
}
