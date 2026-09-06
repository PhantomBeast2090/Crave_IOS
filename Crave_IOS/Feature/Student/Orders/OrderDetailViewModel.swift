import Foundation
import Observation

/// Single-order view model: detail + cancel + tracking status.
@MainActor
@Observable
final class OrderDetailViewModel {
    enum State {
        case idle
        case loading
        case loaded(Order)
        case error(message: String)
    }

    private(set) var state: State = .idle
    private(set) var isCancelling = false
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
        do {
            state = .loaded(try await repository.getOrderById(orderId))
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    func refresh() async {
        state = .idle
        await load()
    }

    /// Apply a realtime status update to the loaded order.
    func applyStatus(_ status: OrderStatus) {
        guard case .loaded(let order) = state, order.status != status else { return }
        Task {
            // Re-fetch for full consistency (timestamps, payment state).
            if let updated = try? await repository.getOrderById(orderId) {
                state = .loaded(updated)
            }
        }
    }

    /// Student cancel (PLACED only — enforced again server-side).
    func cancel(reason: String = "Cancelled by user") async -> Bool {
        guard !isCancelling else { return false }
        isCancelling = true
        defer { isCancelling = false }
        do {
            state = .loaded(try await repository.cancelOrder(orderId: orderId, reason: reason))
            return true
        } catch {
            return false
        }
    }
}
