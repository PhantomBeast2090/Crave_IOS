import Foundation
import Observation

/// Vendor dashboard: today's/active orders + status actions (mirrors Android
/// VendorDashboardScreen). Lists reload on appear, on pull-to-refresh, and
/// after every action — the backend RPC is authoritative for transitions.
@MainActor
@Observable
final class VendorDashboardViewModel {
    enum State {
        case idle
        case loading
        case loaded([Order])
        case error(message: String)
    }

    private(set) var state: State = .idle
    private(set) var actionOrderId: String?
    private(set) var actionError: String?

    private let repository: OrderRepository

    init(repository: OrderRepository) {
        self.repository = repository
    }

    var orders: [Order] {
        if case .loaded(let orders) = state { return orders }
        return []
    }

    var activeOrders: [Order] { orders.filter { $0.status.isActive } }
    var pendingCount: Int { orders.count(where: { $0.status == .placed }) }
    var preparingCount: Int { orders.count(where: { $0.status == .preparing }) }
    var readyCount: Int { orders.count(where: { $0.status == .ready }) }

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
            } else {
                actionError = error.localizedDescription
            }
        }
    }

    // MARK: - Status actions (backend RPCs; UI only shows legal actions)

    func accept(_ order: Order) async { await act(order, action: repository.acceptOrder) }
    func startPreparing(_ order: Order) async { await act(order, action: repository.startPreparing) }
    func markReady(_ order: Order) async { await act(order, action: repository.markReady) }

    func reject(_ order: Order, reason: String = "Rejected by vendor") async {
        await act(order) { [weak self] id in
            guard let self else { throw AppError.message("Cancelled") }
            return try await self.repository.rejectOrder(orderId: id, reason: reason)
        }
    }

    private func act(_ order: Order, action: (String) async throws -> Order) async {
        guard actionOrderId == nil else { return }
        actionOrderId = order.id
        actionError = nil
        defer { actionOrderId = nil }
        do {
            _ = try await action(order.id)
            await fetch()
        } catch is CancellationError {
        } catch {
            actionError = error.localizedDescription
        }
    }
}
