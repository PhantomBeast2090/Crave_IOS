import SwiftUI

/// App-wide theme helpers: brand gradient, app background, key modifiers.
nonisolated enum AppTheme {
    /// Brand gradient used for hero sections and the bottom "checkout" bar.
    static let brandGradient = LinearGradient(
        colors: [GagColors.gradientStart, GagColors.gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Dark hero gradient used for food card image overlays.
    static let heroGradient = LinearGradient(
        colors: [GagColors.gradientDarkStart, GagColors.gradientDarkEnd],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Standard screen background (adaptive).
    static var screenBackground: Color { GagColors.background }
}

/// Card surface style used throughout (adaptive surface + subtle outline).
nonisolated struct GagCardStyle: ViewModifier {
    var padding: CGFloat = GagShapes.spacingL

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(GagColors.surface)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusXLarge))
            .overlay(
                GagShapes.cornerRadius(GagShapes.radiusXLarge)
                    .stroke(GagColors.outlineVariant, lineWidth: 1)
            )
    }
}

extension View {
    /// Apply the standard Crave card surface.
    func gagCard(padding: CGFloat = GagShapes.spacingL) -> some View {
        modifier(GagCardStyle(padding: padding))
    }
}
