import SwiftUI

/// All vendor orders, flat list (mirrors Android VendorOrdersScreen).
struct VendorOrdersView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: VendorOrdersViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading orders…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("All Orders")
        .task { await setupViewModel() }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = VendorOrdersViewModel(repository: appState.repository.orders)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: VendorOrdersViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading orders…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let orders):
            if orders.isEmpty {
                GagEmptyView(icon: "shippingbox", title: "No orders found", message: "")
                    .padding(.top, 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: GagShapes.spacingM) {
                        ForEach(orders) { order in
                            NavigationLink {
                                VendorOrderDetailView(orderId: order.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(order.orderNumber)
                                            .font(GagTypography.titleSmall)
                                            .foregroundStyle(GagColors.onSurface)
                                        Text("\(order.items.reduce(0) { $0 + $1.quantity }) item(s) · \(Formatters.price(order.total))")
                                            .font(GagTypography.bodySmall)
                                            .foregroundStyle(GagColors.onSurfaceVariant)
                                    }
                                    Spacer()
                                    OrderStatusBadge(status: order.status)
                                }
                                .padding(GagShapes.spacingM)
                                .background(GagColors.surface)
                                .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(GagShapes.spacingL)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }
}

#Preview {
    NavigationStack { VendorOrdersView() }
        .environment(AppState())
}
