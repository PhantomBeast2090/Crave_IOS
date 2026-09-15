import SwiftUI

/// Vendor analytics overview (mirrors Android VendorAnalyticsScreen).
struct VendorAnalyticsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: VendorAnalyticsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading analytics…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Analytics")
        .task { await setupViewModel() }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = VendorAnalyticsViewModel(repository: appState.repository.orders)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: VendorAnalyticsViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading analytics…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let revenue, let completed, let topItems):
            ScrollView {
                VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                    Text("Overview")
                        .font(GagTypography.titleMedium)
                        .foregroundStyle(GagColors.onSurface)

                    HStack(spacing: GagShapes.spacingM) {
                        GagStatTile(title: "Total Revenue", value: Formatters.price(revenue))
                        GagStatTile(title: "Completed Orders", value: "\(completed)")
                    }

                    if !topItems.isEmpty {
                        Text("Top Selling Items")
                            .font(GagTypography.titleSmall)
                            .foregroundStyle(GagColors.onSurface)
                        ForEach(topItems) { item in
                            HStack {
                                Text(item.name)
                                    .font(GagTypography.bodyMedium)
                                    .foregroundStyle(GagColors.onSurface)
                                Spacer()
                                Text("\(item.sold) sold")
                                    .font(GagTypography.labelMedium)
                                    .foregroundStyle(GagColors.onSurfaceVariant)
                            }
                            .padding(GagShapes.spacingM)
                            .background(GagColors.surface)
                            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                        }
                    }
                }
                .padding(GagShapes.spacingL)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

}

#Preview {
    NavigationStack { VendorAnalyticsView() }
        .environment(AppState())
}
