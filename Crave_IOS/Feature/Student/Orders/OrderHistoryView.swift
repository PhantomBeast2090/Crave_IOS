import SwiftUI

/// Order history tab — active + past orders from the backend (mirrors
/// Android OrderHistoryScreen).
struct OrderHistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: OrderHistoryViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading orders…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Orders")
        .task { await setupViewModel() }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = OrderHistoryViewModel(repository: appState.repository.orders)
        self.viewModel = vm
        vm.start()
    }

    @ViewBuilder
    private func content(viewModel: OrderHistoryViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading orders…")

        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)

        case .loaded:
            if viewModel.isEmpty {
                GagEmptyView(
                    icon: "shippingbox",
                    title: "No orders yet",
                    message: "Your order history will appear here."
                )
                .padding(.top, 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: GagShapes.spacingM) {
                        if !viewModel.activeOrders.isEmpty {
                            orderSection(title: "Active Orders", orders: viewModel.activeOrders)
                        }
                        if !viewModel.pastOrders.isEmpty {
                            orderSection(title: "Past Orders", orders: viewModel.pastOrders)
                        }
                    }
                    .padding(GagShapes.spacingL)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }

    private func orderSection(title: String, orders: [Order]) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            Text(title)
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)
            ForEach(orders) { order in
                NavigationLink {
                    OrderDetailView(orderId: order.id)
                } label: {
                    OrderHistoryRow(order: order)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct OrderHistoryRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            HStack {
                Text(order.orderNumber)
                    .font(GagTypography.titleSmall)
                    .foregroundStyle(GagColors.onSurface)
                Spacer()
                OrderStatusBadge(status: order.status)
            }
            if !order.outletName.isEmpty {
                Text(order.outletName)
                    .font(GagTypography.bodySmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            Text(order.items.map { "\($0.quantity)× \($0.foodName)" }.joined(separator: ", "))
                .font(GagTypography.bodySmall)
                .foregroundStyle(GagColors.onSurfaceDim)
                .lineLimit(1)
            HStack(spacing: GagShapes.spacingM) {
                if let slot = order.pickupSlot {
                    Label(slot.displayTime, systemImage: "clock")
                }
                Label(Formatters.relativeTime(order.createdAt), systemImage: "calendar")
                Spacer()
                Text(Formatters.price(order.total))
                    .font(GagTypography.titleSmall)
                    .foregroundStyle(GagColors.brandOrange)
            }
            .font(GagTypography.labelMedium)
            .foregroundStyle(GagColors.onSurfaceVariant)
        }
        .padding(GagShapes.spacingM)
        .background(GagColors.surface)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }
}

#Preview {
    NavigationStack { OrderHistoryView() }
        .environment(AppState())
}
