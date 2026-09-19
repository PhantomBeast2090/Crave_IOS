import SwiftUI

/// Lightweight success toast (Android snackbar equivalent). The caller owns
/// presentation + auto-dismiss timing; this is pure UI.
struct GagToast: View {
    let message: String
    var accessibilityIdentifier: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: GagShapes.spacingS) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(GagColors.success)
            Text(message)
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.onSurface)
                .lineLimit(2)
        }
        .padding(.horizontal, GagShapes.spacingL)
        .padding(.vertical, GagShapes.spacingM)
        .background(GagColors.surface)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
        .shadow(radius: 10)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}
