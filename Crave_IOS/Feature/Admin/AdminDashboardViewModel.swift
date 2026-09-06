import Foundation
import Observation

@MainActor
@Observable
final class AdminDashboardViewModel {
    enum State {
        case idle
        case loading
        case loaded(stats: SystemStats, outlets: [Outlet])
        case error(message: String)
    }

    private(set) var state: State = .idle
    private(set) var togglingOutletId: String?
    private(set) var actionError: String?

    private let repository: AppRepository

    init(repository: AppRepository) {
        self.repository = repository
    }

    var stats: SystemStats? {
        if case .loaded(let stats, _) = state { return stats }
        return nil
    }

    var outlets: [Outlet] {
        if case .loaded(_, let outlets) = state { return outlets }
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
            async let stats = repository.admin.getSystemStats()
            async let outlets = repository.outlets.refreshAllOutlets()
            state = .loaded(stats: try await stats, outlets: try await outlets)
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            if stats == nil {
                state = .error(message: error.localizedDescription)
            } else {
                actionError = error.localizedDescription
            }
        }
    }

    func toggleOutlet(_ outlet: Outlet, isOpen: Bool) async {
        guard togglingOutletId == nil else { return }
        togglingOutletId = outlet.id
        actionError = nil
        defer { togglingOutletId = nil }
        do {
            try await repository.admin.toggleOutletStatus(outletId: outlet.id, isOpen: isOpen)
            await fetch()
        } catch is CancellationError {
        } catch {
            actionError = error.localizedDescription
        }
    }
}
