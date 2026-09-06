import SwiftUI

/// Order detail (mirrors Android OrderDetailScreen): header, items, totals,
/// instructions, cancellation reason, and status-appropriate actions.
struct OrderDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: OrderDetailViewModel?
    @State private var showTracking = false
    @State private var showQR = false
    @State private var showCancelConfirm = false
    let orderId: String

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading order…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await setupViewModel() }
        .navigationDestination(isPresented: $showTracking) {
            OrderTrackingView(orderId: orderId)
        }
        .sheet(isPresented: $showQR) {
            NavigationStack { OrderQRView(orderId: orderId) }
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = OrderDetailViewModel(orderId: orderId, repository: appState.repository.orders)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: OrderDetailViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading order…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let order):
            detailContent(order: order, viewModel: viewModel)
        }
    }

    private func detailContent(order: Order, viewModel: OrderDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                headerCard(order)
                itemsCard(order)
                summaryCard(order)

                if let instructions = order.specialInstructions, !instructions.isEmpty {
                    VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                        Text("Special Instructions")
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.onSurface)
                        Text(instructions)
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                    .gagCard()
                }

                if let reason = order.cancellationReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                        Text("Cancellation Reason")
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.error)
                        Text(reason)
                            .font(GagTypography.bodySmall)
                            .foregroundStyle(GagColors.error)
                    }
                    .gagCard()
                }

                actionsSection(order: order, viewModel: viewModel)
            }
            .padding(GagShapes.spacingL)
        }
        .refreshable { await viewModel.refresh() }
        .confirmationDialog("Cancel this order?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Cancel Order", role: .destructive) {
                Task { await viewModel.cancel() }
            }
            Button("Keep Order", role: .cancel) {}
        }
    }

    private func headerCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            HStack {
                Text(order.orderNumber)
                    .font(GagTypography.titleMedium)
                    .foregroundStyle(GagColors.onSurface)
                Spacer()
                OrderStatusBadge(status: order.status)
            }
            if !order.outletName.isEmpty {
                Text(order.outletName)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            HStack(spacing: GagShapes.spacingM) {
                if let slot = order.pickupSlot {
                    Label("Pickup: \(slot.displayTime)", systemImage: "clock")
                        .foregroundStyle(GagColors.info)
                }
                Label(Formatters.relativeTime(order.createdAt), systemImage: "calendar")
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            .font(GagTypography.labelMedium)
        }
        .gagCard()
    }

    private func itemsCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            Text("Items")
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)
            ForEach(order.items) { item in
                HStack(spacing: GagShapes.spacingM) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            VegIndicator(isVeg: item.isVeg)
                            Text(item.foodName)
                                .font(GagTypography.bodyMedium)
                                .foregroundStyle(GagColors.onSurface)
                        }
                        if !item.customizations.isEmpty {
                            Text(item.customizations.joined(separator: ", "))
                                .font(GagTypography.bodySmall)
                                .foregroundStyle(GagColors.onSurfaceVariant)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(item.quantity) × \(Formatters.price(item.unitPrice))")
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                        Text(Formatters.price(item.totalPrice))
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.onSurface)
                    }
                }
            }
        }
        .gagCard()
    }

    private func summaryCard(_ order: Order) -> some View {
        VStack(spacing: GagShapes.spacingS) {
            SummaryRow(label: "Subtotal", value: order.subtotal)
            if order.tax > 0 {
                SummaryRow(label: "Tax & Fees", value: order.tax)
            }
            Divider()
            SummaryRow(label: "Total", value: order.total, isTotal: true)
            HStack {
                Text(order.paymentMethod.displayName)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                Spacer()
                Text(order.paymentStatus.rawValue.capitalized)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(order.paymentStatus.isSettled ? GagColors.success : GagColors.amber)
            }
        }
        .gagCard()
    }

    @ViewBuilder
    private func actionsSection(order: Order, viewModel: OrderDetailViewModel) -> some View {
        if order.status == .ready {
            GagButton(title: "Show Pickup QR", action: { showQR = true })
        }
        if order.status.isActive && order.status != .ready {
            GagButton(title: "Track Order", action: { showTracking = true })
        }
        if order.status == .placed {
            GagButton(
                title: "Cancel Order",
                style: .danger,
                isLoading: viewModel.isCancelling,
                action: { showCancelConfirm = true }
            )
        }
    }
}
