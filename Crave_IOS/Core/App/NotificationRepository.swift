import Foundation

// MARK: - Notification Repository Protocol (mirrors Android)

protocol NotificationRepository: Sendable {
    /// Stream notifications (initial fetch + realtime refetch on changes).
    func observeNotifications() -> AsyncStream<[AppNotification]>

    /// Fetch from backend, newest first.
    func refreshNotifications() async throws -> [AppNotification]

    /// Current unread count (for the tab badge).
    func unreadCount() async -> Int

    /// Mark one notification read (scoped to the current user server-side).
    func markAsRead(_ notificationId: String) async throws
}
