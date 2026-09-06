import SwiftUI

/// Live order tracking with Realtime status updates (mirrors Android
/// LiveOrderTrackingScreen).
struct OrderTrackingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: OrderTrackingViewModel?
    @State private var showQR = false
    let orderId: String

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading tracking…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Order Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await setupViewModel() }
        .sheet(isPresented: $showQR) {
            NavigationStack { OrderQRView(orderId: orderId) }
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = OrderTrackingViewModel(orderId: orderId, repository: appState.repository.orders)
        self.viewModel = vm
        vm.start()
    }

    @ViewBuilder
    private func content(viewModel: OrderTrackingViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading tracking…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.retry() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let order):
            trackingContent(order)
        }
    }

    private func trackingContent(_ order: Order) -> some View {
        ScrollView {
            VStack(spacing: GagShapes.spacingL) {
                VStack(spacing: GagShapes.spacingS) {
                    HStack {
                        Text(order.orderNumber)
                            .font(GagTypography.titleMedium)
                            .foregroundStyle(GagColors.onSurface)
                        Spacer()
                        Text(Formatters.price(order.total))
                            .font(GagTypography.titleMedium)
                            .foregroundStyle(GagColors.brandOrange)
                    }
                    if !order.outletName.isEmpty {
                        Text(order.outletName)
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        if let slot = order.pickupSlot {
                            Label("Pickup: \(slot.displayTime)", systemImage: "clock")
                                .foregroundStyle(GagColors.info)
                        }
                        Text("\(order.items.reduce(0) { $0 + $1.quantity }) item(s)")
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                    .font(GagTypography.labelMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .gagCard()

                statusHero(order.status)
                OrderTimelineView(status: order.status)

                if order.status == .ready {
                    GagButton(title: "Show Pickup QR", action: { showQR = true })
                }
            }
            .padding(GagShapes.spacingL)
        }
        .refreshable {
            await viewModel?.retry()
        }
    }

    private func statusHero(_ status: OrderStatus) -> some View {
        VStack(spacing: GagShapes.spacingS) {
            Image(systemName: status == .ready ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 60))
                .foregroundStyle(status == .ready ? GagColors.success : GagColors.brandOrange)
            Text(status == .ready ? "Your order is ready! 🎉" : "Preparing your order…")
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.onSurface)
            Text(status.displayName)
                .font(GagTypography.bodyMedium)
                .foregroundStyle(GagColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GagShapes.spacingM)
    }
}
