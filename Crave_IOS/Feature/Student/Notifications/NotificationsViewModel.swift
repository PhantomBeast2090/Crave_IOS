import Foundation
import Observation

@MainActor
@Observable
final class NotificationsViewModel {
    enum State {
        case idle
        case loading
        case loaded([AppNotification])
        case error(message: String)
    }

    private(set) var state: State = .idle
    private let repository: NotificationRepository
    private var observeTask: Task<Void, Never>?

    init(repository: NotificationRepository) {
        self.repository = repository
    }

    var unreadCount: Int {
        if case .loaded(let items) = state { return items.filter { !$0.isRead }.count }
        return 0
    }

    func start() {
        guard observeTask == nil else { return }
        // Push preference is real: with notifications off we fetch once and
        // skip the Realtime subscription entirely.
        guard UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true else {
            Task { [weak self] in await self?.refresh() }
            return
        }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.repository.observeNotifications() {
                if case .error = self.state, items.isEmpty { continue }
                self.state = .loaded(items)
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
            if case .loaded(let items) = state { return !items.isEmpty }
            return false
        }()
        if !hadData { state = .loading }
        do {
            state = .loaded(try await repository.refreshNotifications())
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch {
            if !hadData { state = .error(message: error.localizedDescription) }
        }
    }

    /// Mark read (realtime feed reconciles); returns order id for deep-link.
    func open(_ notification: AppNotification) async -> String? {
        if !notification.isRead {
            try? await repository.markAsRead(notification.id)
            await refresh()
        }
        return notification.orderId
    }
}
