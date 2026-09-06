import SwiftUI

/// Admin console (mirrors Android AdminDashboardScreen): system stats from
/// `get_admin_stats` + outlet open/closed management via
/// `admin_toggle_outlet_status`.
struct AdminFlow: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: AdminDashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel: viewModel)
                } else {
                    GagLoadingView(message: "Loading admin console…")
                }
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Admin Console")
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
            .task { await setupViewModel() }
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = AdminDashboardViewModel(repository: appState.repository)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: AdminDashboardViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading admin console…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let stats, let outlets):
            ScrollView {
                VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                    statsGrid(stats)
                    if let actionError = viewModel.actionError {
                        Text(actionError)
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.error)
                    }
                    outletsSection(outlets, viewModel: viewModel)
                }
                .padding(GagShapes.spacingL)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    private func statsGrid(_ stats: SystemStats) -> some View {
        VStack(spacing: GagShapes.spacingM) {
            HStack(spacing: GagShapes.spacingM) {
                AdminStatBox(title: "Total Users", value: "\(stats.totalUsers)")
                AdminStatBox(title: "Total Vendors", value: "\(stats.totalVendors)")
                AdminStatBox(title: "Total Outlets", value: "\(stats.totalOutlets)")
            }
            HStack(spacing: GagShapes.spacingM) {
                AdminStatBox(title: "Total Orders", value: "\(stats.totalOrders)")
                AdminStatBox(title: "Active Orders", value: "\(stats.activeOrders)")
                AdminStatBox(title: "Completed", value: "\(stats.completedOrders)")
            }
            HStack(spacing: GagShapes.spacingM) {
                AdminStatBox(title: "Revenue", value: Formatters.price(stats.revenue))
                AdminStatBox(title: "Orders Today", value: "\(stats.ordersToday)")
                AdminStatBox(title: "Revenue Today", value: Formatters.price(stats.revenueToday))
            }
        }
    }

    private func outletsSection(_ outlets: [Outlet], viewModel: AdminDashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            Text("Manage Outlets")
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)
            ForEach(outlets) { outlet in
                HStack(spacing: GagShapes.spacingM) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(outlet.name)
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.onSurface)
                        Text(outlet.location.building.isEmpty ? (outlet.isActive ? "Active" : "Inactive") : outlet.location.building)
                            .font(GagTypography.labelSmall)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                    Spacer()
                    if viewModel.togglingOutletId == outlet.id {
                        ProgressView().tint(GagColors.brandOrange)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { outlet.isOpen },
                            set: { newValue in Task { await viewModel.toggleOutlet(outlet, isOpen: newValue) } }
                        ))
                        .labelsHidden()
                        .tint(GagColors.success)
                    }
                }
                .padding(GagShapes.spacingM)
                .background(GagColors.surface)
                .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
            }
        }
    }
}

struct AdminStatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.brandOrange)
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
        .background(GagColors.surfaceVariant)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }
}

#Preview {
    AdminFlow()
        .environment(AppState())
}
