import Foundation

/// A pickup time slot. Capacity is decided by the backend — never client-side.
nonisolated struct PickupSlot: Sendable, Hashable, Identifiable {
    let id: String
    let outletId: String
    /// "12:30"
    let startTime: String
    /// "12:40"
    let endTime: String
    /// "2024-01-15"
    let date: String
    let capacity: Int
    let bookedCount: Int
    let status: SlotStatus

    var availableCount: Int { max(capacity - bookedCount, 0) }
    var displayTime: String { "\(startTime) – \(endTime)" }
    var isSelectable: Bool { status != .full }
}

nonisolated enum SlotStatus: String, Sendable, Codable, CaseIterable {
    case available = "AVAILABLE"
    case limited = "LIMITED"
    case full = "FULL"

    init(fromString raw: String) {
        switch raw.uppercased() {
        case "FULL": self = .full
        case "LIMITED": self = .limited
        default: self = .available
        }
    }
}

/// Review model (outlet or food).
nonisolated struct Review: Sendable, Hashable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let outletId: String?
    let foodItemId: String?
    /// 1–5
    let rating: Int
    let comment: String?
    let createdAt: String
}

/// A favourited food item.
nonisolated struct Favorite: Sendable, Hashable, Identifiable {
    let foodItemId: String
    let foodItem: FoodItem

    var id: String { foodItemId }
}
