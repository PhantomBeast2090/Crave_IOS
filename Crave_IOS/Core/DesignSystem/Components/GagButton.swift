import SwiftUI

/// Primary/secondary/ghost button used across the app.
struct GagButton: View {
    enum Style {
        case primary
        case secondary
        case ghost
        case danger

        var background: Color {
            switch self {
            case .primary: return GagColors.brandOrange
            case .secondary: return GagColors.surfaceVariant
            case .ghost: return .clear
            case .danger: return GagColors.error
            }
        }

        var foreground: Color {
            switch self {
            case .primary: return .white
            case .secondary: return GagColors.onSurface
            case .ghost: return GagColors.brandOrange
            case .danger: return .white
            }
        }
    }

    let title: String
    var style: Style = .primary
    var isLoading = false
    var isEnabled = true
    /// UI-test hook. Nil by default — never affects production behavior.
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: GagShapes.spacingS) {
                if isLoading {
                    ProgressView()
                        .tint(style.foreground)
                } else {
                    Text(title)
                        .font(GagTypography.labelLarge)
                }
            }
            .foregroundStyle(style.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(style.background)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
        }
        .buttonStyle(.plain)
        .modifier(AccessibilityIdentifierModifier(id: accessibilityIdentifier))
        .opacity((isEnabled && !isLoading) ? 1 : 0.5)
        .disabled(!isEnabled || isLoading)
    }
}

/// Applies an accessibility identifier only when one is provided, so default
/// label-derived accessibility is never disturbed.
struct AccessibilityIdentifierModifier: ViewModifier {
    let id: String?
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        GagButton(title: "Continue", action: {})
        GagButton(title: "Secondary", style: .secondary, action: {})
        GagButton(title: "Loading", isLoading: true, action: {})
        GagButton(title: "Danger", style: .danger, action: {})
    }
    .padding()
}
