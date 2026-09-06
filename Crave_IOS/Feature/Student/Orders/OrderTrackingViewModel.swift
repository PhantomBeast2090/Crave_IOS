import Foundation
import Observation

/// Live tracking: initial detail + Realtime status updates (no manual
/// refresh needed — mirrors Android LiveOrderTrackingScreen).
@MainActor
@Observable
final class OrderTrackingViewModel {
    enum State {
        case idle
        case loading
        case loaded(Order)
        case error(message: String)
    }

    private(set) var state: State = .idle
    let orderId: String
    private let repository: OrderRepository
    private var statusTask: Task<Void, Never>?

    init(orderId: String, repository: OrderRepository) {
        self.orderId = orderId
        self.repository = repository
    }

    var order: Order? {
        if case .loaded(let order) = state { return order }
        return nil
    }

    func start() {
        Task { await load() }
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            guard let self else { return }
            for await status in self.repository.observeOrderStatus(orderId: self.orderId) {
                if Task.isCancelled { break }
                await self.applyStatus(status)
            }
        }
    }

    func stop() {
        statusTask?.cancel()
        statusTask = nil
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

    func retry() async {
        state = .idle
        await load()
    }

    private func applyStatus(_ status: OrderStatus) async {
        guard case .loaded = state else { return }
        // Re-fetch for full consistency (timestamps, payment state).
        if let updated = try? await repository.getOrderById(orderId) {
            state = .loaded(updated)
        }
    }
}
