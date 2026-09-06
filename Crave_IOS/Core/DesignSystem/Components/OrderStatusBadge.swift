import SwiftUI

/// Status pill used across order lists, details, and tracking.
struct OrderStatusBadge: View {
    let status: OrderStatus

    var body: some View {
        Text(status.displayName)
            .font(GagTypography.labelSmall)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12))
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusPill))
    }

    private var statusColor: Color {
        switch status {
        case .placed, .accepted: return GagColors.statusPlaced
        case .preparing: return GagColors.statusPreparing
        case .ready: return GagColors.statusReady
        case .pickedUp: return GagColors.statusPickedUp
        case .cancelled, .rejected, .expired: return GagColors.statusCancelled
        case .refunded: return GagColors.statusRefunded
        default: return GagColors.statusCreated
        }
    }
}
