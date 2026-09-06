import SwiftUI

/// Explicit − / + quantity control (Android QuantitySelector parity).
/// Chosen over SwiftUI Stepper: larger touch targets, visible state at the
/// limits, and stable accessibility for both users and UI tests.
struct QuantitySelector: View {
    let quantity: Int
    var min: Int = 1
    var max: Int = 10
    var onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: GagShapes.spacingS) {
            Button {
                onChange(Swift.max(min, quantity - 1))
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(quantity <= min ? GagColors.onSurfaceDim : GagColors.brandOrange)
                    .frame(width: 32, height: 32)
                    .background(GagColors.surfaceVariant)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("decreaseQuantity")
            .disabled(quantity <= min)

            Text("\(quantity)")
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.onSurface)
                .frame(minWidth: 28)
                .accessibilityIdentifier("quantityValue")

            Button {
                onChange(Swift.min(max, quantity + 1))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(quantity >= max ? GagColors.onSurfaceDim : GagColors.brandOrange)
                    .frame(width: 32, height: 32)
                    .background(GagColors.surfaceVariant)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("increaseQuantity")
            .disabled(quantity >= max)
        }
    }
}
