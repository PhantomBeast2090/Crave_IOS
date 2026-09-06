import Foundation
import Supabase

/// Notifications: backend fetch + Realtime refetch (mirrors Android's
/// callbackFlow + postgresChangeFlow on `public:notifications`).
@MainActor
final class SupabaseNotificationRepository: NotificationRepository, Sendable {
    private let client: SupabaseClient
    private var latest: [AppNotification] = []

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    private var userId: String? { client.auth.currentSession?.user.id.uuidString }

    func observeNotifications() -> AsyncStream<[AppNotification]> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                let initial = (try? await self.refreshNotifications()) ?? []
                continuation.yield(initial)
                guard let uid = self.userId else {
                    continuation.finish()
                    return
                }
                let channel = self.client.realtimeV2.channel("notifications-\(uid)")
                let events = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "notifications",
                    filter: .eq("user_id", value: uid)
                )
                do {
                    try await channel.subscribe()
                } catch {
                    print("⚠️ [Notifications] realtime subscribe failed: \(error)")
                    continuation.finish()
                    return
                }
                for await _ in events {
                    if Task.isCancelled { break }
                    let updated = (try? await self.refreshNotifications()) ?? self.latest
                    continuation.yield(updated)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @discardableResult
    func refreshNotifications() async throws -> [AppNotification] {
        guard let uid = userId else {
            latest = []
            return []
        }
        let dtos: [NotificationDto]
        do {
            dtos = try await client.from("notifications")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("❌ [Notifications] refresh failed: \(describeDecodingError(error))")
            if latest.isEmpty { throw AppError.message("Couldn't load notifications: \(describeDecodingError(error))") }
            return latest
        }
        latest = dtos.map { $0.toDomain() }
        return latest
    }

    func unreadCount() async -> Int {
        latest.filter { !$0.isRead }.count
    }

    func markAsRead(_ notificationId: String) async throws {
        guard let uid = userId else { return }
        struct ReadUpdate: Encodable, Sendable { let isRead: Bool
            enum CodingKeys: String, CodingKey { case isRead = "is_read" } }
        do {
            try await client.from("notifications")
                .update(ReadUpdate(isRead: true))
                .eq("id", value: notificationId)
                .eq("user_id", value: uid)
                .execute()
        } catch {
            throw AppError.message("Couldn't mark notification as read.")
        }
        latest = latest.map { n in
            n.id == notificationId
                ? AppNotification(id: n.id, title: n.title, body: n.body, type: n.type,
                                  orderId: n.orderId, isRead: true, deepLink: n.deepLink,
                                  createdAt: n.createdAt)
                : n
        }
    }
}
