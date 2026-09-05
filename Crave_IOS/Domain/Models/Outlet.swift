import Foundation

/// A food outlet / canteen.
nonisolated struct Outlet: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String?
    let location: OutletLocation
    let isOpen: Bool
    let operatingHours: OperatingHours
    let currentQueueSize: Int
    let estimatedWaitMinutes: Int
    let categories: [String]
    let rating: Double
    let totalReviews: Int
    let vendorId: String
    let isActive: Bool
    let phone: String?

    var queueLevel: QueueLevel { QueueLevel.fromQueueSize(currentQueueSize) }
}

nonisolated struct OutletLocation: Sendable, Hashable {
    let building: String
    let floor: String
    let description: String
    let latitude: Double?
    let longitude: Double?
}

nonisolated struct OperatingHours: Sendable, Hashable {
    /// "08:00"
    let openTime: String
    /// "22:00"
    let closeTime: String
    /// ["Mon", "Tue", ...]
    let daysOpen: [String]
}

/// Queue level derived from queue size.
nonisolated enum QueueLevel: String, Sendable, Hashable {
    case low, moderate, high, veryHigh

    static func fromQueueSize(_ size: Int) -> QueueLevel {
        switch size {
        case ...5: return .low
        case 6...15: return .moderate
        case 16...30: return .high
        default: return .veryHigh
        }
    }

    var label: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}
