import SwiftUI

/// Admin main flow — dashboard + sign out.
struct AdminFlow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                    GagEmptyView(
                        icon: "chart.bar.xaxis",
                        title: "Admin Dashboard",
                        message: "Stats, outlet management, and moderation arrive in the admin stage (get_admin_stats + admin_toggle_outlet_status)."
                    )
                }
                .padding(GagShapes.spacingL)
            }
            .background(GagColors.background)
            .navigationTitle("Admin")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await appState.signOut() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(GagColors.error)
                    }
                }
            }
        }
    }
}

#Preview {
    AdminFlow()
        .environment(AppState())
}
