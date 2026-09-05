import SwiftUI

/// Vendor dashboard scaffold — filled with real order/stats data in the
/// vendor stage (vendor RPCs + realtime).
struct VendorDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                Text("Today")
                    .font(GagTypography.titleLarge)
                    .foregroundStyle(GagColors.onSurface)

                GagEmptyView(
                    icon: "clock",
                    title: "No active orders",
                    message: "New orders for your outlet will appear here in real time."
                )
            }
            .padding(GagShapes.spacingL)
        }
        .background(GagColors.background)
        .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack { VendorDashboardView() }
}
