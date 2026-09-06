import SwiftUI

/// Order progress timeline (mirrors Android LiveOrderTrackingScreen steps):
/// Order Placed → Accepted → Preparing → Ready. Terminal states render a
/// final banner instead of the step list.
struct OrderTimelineView: View {
    let status: OrderStatus

    private static let steps: [(OrderStatus, String)] = [
        (.placed, "Order Placed"),
        (.accepted, "Accepted"),
        (.preparing, "Preparing"),
        (.ready, "Ready for Pickup!"),
    ]

    private var stepOrder: [OrderStatus] { [.placed, .accepted, .preparing, .ready] }

    var body: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            if status.isTerminal || status == .created {
                terminalBanner
            } else {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                    stepRow(index: index, status: step.0, label: step.1)
                }
            }
        }
        .padding(GagShapes.spacingL)
        .background(GagColors.surface)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }

    private var terminalBanner: some View {
        HStack(spacing: GagShapes.spacingM) {
            Image(systemName: status == .pickedUp ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(status == .pickedUp ? GagColors.success : GagColors.onSurfaceVariant)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.displayName)
                    .font(GagTypography.titleMedium)
                    .foregroundStyle(GagColors.onSurface)
                Text(terminalMessage)
                    .font(GagTypography.bodySmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
        }
    }

    private var terminalMessage: String {
        switch status {
        case .pickedUp: return "Enjoy your meal!"
        case .cancelled: return "This order was cancelled."
        case .rejected: return "This order was rejected by the outlet."
        case .expired: return "This order expired."
        case .refunded: return "This order was refunded."
        default: return "Waiting for the outlet to accept your order."
        }
    }

    private func stepRow(index: Int, status step: OrderStatus, label: String) -> some View {
        let currentIndex = stepOrder.firstIndex(of: status) ?? -1
        let isDone = index < currentIndex || status == .pickedUp
        let isCurrent = index == currentIndex

        return HStack(spacing: GagShapes.spacingM) {
            ZStack {
                Circle()
                    .fill(isDone ? GagColors.success : (isCurrent ? GagColors.brandOrange : GagColors.surfaceVariant))
                    .frame(width: 32, height: 32)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(GagTypography.labelLarge)
                        .foregroundStyle(isCurrent ? .white : GagColors.onSurfaceVariant)
                }
            }
            Text(label)
                .font(isCurrent ? GagTypography.titleSmall : GagTypography.bodyMedium)
                .foregroundStyle(isDone || isCurrent ? GagColors.onSurface : GagColors.onSurfaceDim)
            Spacer()
        }
    }
}
