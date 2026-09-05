import Foundation

/// Complete order lifecycle model.
/// The server is ALWAYS authoritative for order status — never set status client-side.
nonisolated struct Order: Sendable, Hashable, Identifiable {
    let id: String
    /// Human-readable number, e.g. "GAG-20240115-ABC123"
    let orderNumber: String
    let userId: String
    let vendorId: String
    let outletId: String
    let outletName: String
    let items: [OrderItem]
    let subtotal: Double
    let tax: Double
    let total: Double
    let status: OrderStatus
    let pickupSlot: PickupSlot?
    let estimatedPrepMinutes: Int
    let actualPrepMinutes: Int?
    let createdAt: String
    let placedAt: String?
    let acceptedAt: String?
    let preparingAt: String?
    let readyAt: String?
    let pickedUpAt: String?
    let cancelledAt: String?
    let cancellationReason: String?
    let paymentStatus: PaymentStatus
    let paymentMethod: PaymentMethod
    let specialInstructions: String?
    /// Short-lived pickup token (not sensitive by itself).
    let qrToken: String?
}

nonisolated struct OrderItem: Sendable, Hashable, Identifiable {
    let id: String
    let foodItemId: String
    let foodName: String
    let foodImageUrl: String?
    let quantity: Int
    let unitPrice: Double
    let totalPrice: Double
    let customizations: [String]
    let isVeg: Bool
}

nonisolated enum OrderStatus: String, Sendable, Codable, CaseIterable {
    case created = "CREATED"
    case placed = "PLACED"
    case accepted = "ACCEPTED"
    case preparing = "PREPARING"
    case ready = "READY"
    case pickedUp = "PICKED_UP"
    case rejected = "REJECTED"
    case cancelled = "CANCELLED"
    case expired = "EXPIRED"
    case refunded = "REFUNDED"

    init(fromString raw: String) {
        self = OrderStatus(rawValue: raw.uppercased()) ?? .created
    }

    var isTerminal: Bool {
        switch self {
        case .pickedUp, .rejected, .cancelled, .expired, .refunded: return true
        default: return false
        }
    }

    var isActive: Bool {
        switch self {
        case .placed, .accepted, .preparing, .ready: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .created: return "Created"
        case .placed: return "Order Placed"
        case .accepted: return "Accepted"
        case .preparing: return "Preparing"
        case .ready: return "Ready for Pickup"
        case .pickedUp: return "Picked Up"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        case .refunded: return "Refunded"
        }
    }
}

nonisolated enum PaymentStatus: String, Sendable, Codable, CaseIterable {
    case pending = "PENDING"
    case paid = "PAID"
    case failed = "FAILED"
    case refunded = "REFUNDED"
    case created = "CREATED"
    case authorized = "AUTHORIZED"
    case captured = "CAPTURED"

    init(fromString raw: String) {
        self = PaymentStatus(rawValue: raw.uppercased()) ?? .pending
    }

    var isSettled: Bool { self == .paid || self == .captured }
}

nonisolated enum PaymentMethod: String, Sendable, Codable, CaseIterable {
    case payAtCounter = "PAY_AT_COUNTER"
    case online = "ONLINE"

    init(fromString raw: String) {
        self = raw.uppercased() == "ONLINE" ? .online : .payAtCounter
    }

    var displayName: String {
        switch self {
        case .payAtCounter: return "Pay at Counter"
        case .online: return "Online Payment"
        }
    }
}
