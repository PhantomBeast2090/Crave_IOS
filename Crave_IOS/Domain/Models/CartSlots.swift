import Foundation

/// Pure slot-matching logic for multi-outlet carts (unit-tested).
///
/// A common window exists only when outlets share the EXACT start/end time —
/// outlet schedules are never interpolated or fabricated. Capacity is never
/// decided here; the server re-validates every slot at placement.
nonisolated enum SlotMatcher: Sendable {
    /// A start/end window shared by outlets.
    struct CommonWindow: Sendable, Hashable {
        let startTime: String
        let endTime: String

        var displayTime: String { "\(startTime) – \(endTime)" }
    }

    /// Common selectable windows across all given outlet slot lists, earliest
    /// first. Outlets with no selectable slots eliminate all common windows.
    static func commonWindows(slotsByOutlet: [String: [PickupSlot]]) -> [CommonWindow] {
        guard !slotsByOutlet.isEmpty else { return [] }
        let lists = slotsByOutlet.values.map { slots in
            Set(slots.filter(\.isSelectable).map { CommonWindow(startTime: $0.startTime, endTime: $0.endTime) })
        }
        guard let first = lists.first else { return [] }
        let common = lists.dropFirst().reduce(first) { $0.intersection($1) }
        return common.sorted {
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.endTime < $1.endTime
        }
    }

    /// Slot id per outlet realizing a common window. Outlets without a slot
    /// in the window are absent from the result (caller must handle gaps —
    /// never assign an invalid slot).
    static func slotIds(
        for window: CommonWindow,
        in slotsByOutlet: [String: [PickupSlot]]
    ) -> [String: String] {
        var result: [String: String] = [:]
        for (outletId, slots) in slotsByOutlet {
            if let slot = slots.first(where: {
                $0.isSelectable && $0.startTime == window.startTime && $0.endTime == window.endTime
            }) {
                result[outletId] = slot.id
            }
        }
        return result
    }
}
