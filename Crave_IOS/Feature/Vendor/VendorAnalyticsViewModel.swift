import Foundation
import Observation

/// Vendor analytics from real orders (mirrors Android VendorAnalyticsScreen):
/// revenue + completed count over PICKED_UP orders, top-5 items by quantity.
@MainActor
@Observable
final class VendorAnalyticsViewModel {
    struct TopItem: Identifiable, Equatable {
        let name: String
        var id: String { name }
        let sold: Int
    }

    enum State {
        case idle
        case loading
        case loaded(totalRevenue: Double, completedOrders: Int, topItems: [TopItem])
        case error(message: String)
    }

    private(set) var state: State = .idle
    private let repository: OrderRepository

    init(repository: OrderRepository) {
        self.repository = repository
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
            let orders = try await repository.getVendorOrders(status: nil)
            let completed = orders.filter { $0.status == .pickedUp }
            let revenue = completed.reduce(0) { $0 + $1.total }
            var counts: [String: Int] = [:]
            for order in completed {
                for item in order.items {
                    counts[item.foodName, default: 0] += item.quantity
                }
            }
            let top = counts.map { TopItem(name: $0.key, sold: $0.value) }
                .sorted { $0.sold > $1.sold }
                .prefix(5)
                .map { $0 }
            state = .loaded(totalRevenue: revenue, completedOrders: completed.count, topItems: top)
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
}
