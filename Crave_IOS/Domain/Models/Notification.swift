import Foundation

/// In-app notification model.
nonisolated struct AppNotification: Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let body: String
    let type: NotificationType
    let orderId: String?
    let isRead: Bool
    let deepLink: String?
    let createdAt: String
}

nonisolated enum NotificationType: String, Sendable, CaseIterable {
    case general = "GENERAL"
    case orderPlaced = "ORDER_PLACED"
    case orderAccepted = "ORDER_ACCEPTED"
    case orderPreparing = "ORDER_PREPARING"
    case orderReady = "ORDER_READY"
    case orderPickedUp = "ORDER_PICKED_UP"
    case orderCancelled = "ORDER_CANCELLED"
    case orderRejected = "ORDER_REJECTED"

    init(fromString raw: String) {
        self = NotificationType(rawValue: raw.uppercased()) ?? .general
    }

    var icon: String {
        switch self {
        case .general: return "bell"
        case .orderPlaced: return "shippingbox"
        case .orderAccepted: return "checkmark.circle"
        case .orderPreparing: return "flame"
        case .orderReady: return "hand.raised.fill"
        case .orderPickedUp: return "bag.fill"
        case .orderCancelled, .orderRejected: return "xmark.octagon"
        }
    }
}
