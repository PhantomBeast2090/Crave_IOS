import SwiftUI

/// Text field / secure field with label, placeholder, and error state.
struct GagTextField: View {
    enum FieldKind {
        case plain
        case secure
    }

    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var kind: FieldKind = .plain
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var errorMessage: String? = nil
    /// UI-test hook. Nil by default — never affects production behavior.
    var accessibilityIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingXS) {
            Text(title)
                .font(GagTypography.labelMedium)
                .foregroundStyle(GagColors.onSurfaceVariant)

            Group {
                switch kind {
                case .plain:
                    TextField(placeholder, text: $text)
                case .secure:
                    SecureField(placeholder, text: $text)
                }
            }
            .font(GagTypography.bodyLarge)
            .foregroundStyle(GagColors.onSurface)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .modifier(AccessibilityIdentifierModifier(id: accessibilityIdentifier))
            .padding(.horizontal, GagShapes.spacingL)
            .frame(height: 48)
            .background(GagColors.surfaceVariant)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusMedium))
            .overlay(
                GagShapes.cornerRadius(GagShapes.radiusMedium)
                    .stroke(errorMessage == nil ? GagColors.outlineVariant : GagColors.error, lineWidth: 1)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(GagTypography.labelSmall)
                    .foregroundStyle(GagColors.error)
            }
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack(spacing: 16) {
        GagTextField(title: "Email", text: $text, placeholder: "you@srmist.edu.in", keyboardType: .emailAddress)
        GagTextField(title: "Password", text: $text, kind: .secure, errorMessage: "Required")
    }
    .padding()
}
