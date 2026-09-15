import SwiftUI

/// Shared stat tile for vendor dashboard, vendor analytics, and admin
/// dashboard. Value in the accent color on a matching tint; title below.
struct GagStatTile: View {
    let title: String
    let value: String
    var accent: Color = GagColors.brandOrange

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(GagTypography.titleLarge)
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(GagTypography.labelSmall)
                .foregroundStyle(GagColors.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GagShapes.spacingM)
        .background(accent.opacity(0.12))
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }
}
