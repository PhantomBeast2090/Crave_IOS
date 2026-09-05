import SwiftUI

/// Top app bar with optional back button and trailing actions.
struct GagTopBar: View {
    let title: String
    var subtitle: String? = nil
    var showsBack: Bool = false
    var onBack: (() -> Void)? = nil
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        HStack(spacing: GagShapes.spacingM) {
            if showsBack {
                Button {
                    onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GagColors.onSurface)
                        .frame(width: 36, height: 36)
                        .background(GagColors.surfaceVariant)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GagTypography.titleLarge)
                    .foregroundStyle(GagColors.onSurface)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
            }

            Spacer(minLength: 0)

            trailing.map { $0() }
        }
        .padding(.horizontal, GagShapes.spacingL)
        .padding(.vertical, GagShapes.spacingS)
        .background(GagColors.background)
    }
}

#Preview {
    GagTopBar(title: "Outlets", subtitle: "SRM Kattankulathur", showsBack: true)
}
