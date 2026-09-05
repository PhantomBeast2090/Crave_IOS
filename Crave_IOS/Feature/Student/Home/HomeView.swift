import SwiftUI

/// Student home feed. Fleshed out with real outlet/category data once the
/// outlet repository is wired to Supabase.
struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                heroHeader

                if !appState.isBackendConfigured {
                    GagNotConfiguredBanner()
                        .padding(.horizontal, GagShapes.spacingL)
                }

                SectionHeader(title: "Categories", icon: "square.grid.2x2")
                    .padding(.horizontal, GagShapes.spacingL)
                categoryChips

                SectionHeader(title: "Outlets near you", icon: "storefront")
                    .padding(.horizontal, GagShapes.spacingL)

                if appState.isBackendConfigured {
                    GagLoadingView(message: "Fetching outlets…")
                        .frame(height: 220)
                } else {
                    GagEmptyView(
                        icon: "shippingbox",
                        title: "Nothing here yet",
                        message: "Once the backend key is configured, outlet listings will appear here."
                    )
                }
            }
            .padding(.vertical, GagShapes.spacingM)
        }
        .background(GagColors.background)
        .navigationTitle("Home")
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: GagShapes.radiusXXLarge, style: .continuous)
                .fill(AppTheme.brandGradient)
                .frame(height: 160)

            VStack(alignment: .leading, spacing: 4) {
                Text("Hi there 👋")
                    .font(GagTypography.titleLarge)
                    .foregroundStyle(.white)
                Text("Order ahead from campus outlets and skip the queue.")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(GagShapes.spacingXL)
        }
        .padding(.horizontal, GagShapes.spacingL)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GagShapes.spacingS) {
                ForEach(["🍔 Meals", "🍕 Pizza", "🥤 Beverages", "🍟 Snacks", "🥡 Chinese", "🍰 Desserts"], id: \.self) { chip in
                    Text(chip)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.onSurface)
                        .padding(.horizontal, GagShapes.spacingL)
                        .padding(.vertical, GagShapes.spacingS)
                        .background(GagColors.surfaceVariant)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, GagShapes.spacingL)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: GagShapes.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GagColors.brandOrange)
            Text(title)
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.onSurface)
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(AppState())
}
