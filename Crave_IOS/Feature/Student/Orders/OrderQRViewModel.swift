import Foundation
import Observation

@MainActor
@Observable
final class OrderQRViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(token: String, expiresAt: String?)
        case error(message: String)
    }

    private(set) var state: State = .idle
    let orderId: String
    private let repository: OrderRepository

    init(orderId: String, repository: OrderRepository) {
        self.orderId = orderId
        self.repository = repository
    }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            let (token, expiresAt) = try await repository.getPickupToken(orderId: orderId)
            state = .loaded(token: token, expiresAt: expiresAt)
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
}
