import SwiftUI

/// Vendor order detail (mirrors Android VendorOrderDetailScreen): header,
/// items, and legal status actions.
struct VendorOrderDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: VendorOrderDetailViewModel?
    @State private var showRejectConfirm = false
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
        .task { await setupViewModel() }
        .confirmationDialog("Reject this order?", isPresented: $showRejectConfirm, titleVisibility: .visible) {
            Button("Reject Order", role: .destructive) {
                Task { await viewModel?.reject() }
            }
            Button("Keep Order", role: .cancel) {}
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = VendorOrderDetailViewModel(orderId: orderId, repository: appState.repository.orders)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: VendorOrderDetailViewModel) -> some View {
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

    private func detailContent(order: Order, viewModel: VendorOrderDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                    HStack {
                        Text("Order \(order.orderNumber)")
                            .font(GagTypography.titleMedium)
                            .foregroundStyle(GagColors.onSurface)
                        Spacer()
                        OrderStatusBadge(status: order.status)
                    }
                    Text("Pickup: \(order.pickupSlot?.displayTime ?? "N/A")")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                    if let note = order.specialInstructions, !note.isEmpty {
                        Text("Note: \(note)")
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.amber)
                    }
                }
                .gagCard()

                VStack(alignment: .leading, spacing: GagShapes.spacingM) {
                    Text("Items")
                        .font(GagTypography.titleSmall)
                        .foregroundStyle(GagColors.onSurface)
                    ForEach(order.items) { item in
                        HStack {
                            Text("\(item.foodName) × \(item.quantity)")
                                .font(GagTypography.bodyMedium)
                                .foregroundStyle(GagColors.onSurface)
                            Spacer()
                            Text(Formatters.price(item.totalPrice))
                                .font(GagTypography.bodyMedium)
                                .foregroundStyle(GagColors.onSurface)
                        }
                        if !item.customizations.isEmpty {
                            Text(item.customizations.joined(separator: ", "))
                                .font(GagTypography.bodySmall)
                                .foregroundStyle(GagColors.onSurfaceVariant)
                        }
                    }
                    Divider()
                    SummaryRow(label: "Total", value: order.total, isTotal: true)
                }
                .gagCard()

                if let actionError = viewModel.actionError {
                    Text(actionError)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.error)
                }

                if viewModel.isActing {
                    HStack {
                        ProgressView().tint(GagColors.brandOrange)
                        Text("Updating…")
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                } else {
                    vendorActions(order: order, viewModel: viewModel)
                }

                if order.status == .ready {
                    Text("Ask the student to show their pickup QR, then scan it from the Dashboard.")
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
            }
            .padding(GagShapes.spacingL)
        }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func vendorActions(order: Order, viewModel: VendorOrderDetailViewModel) -> some View {
        switch order.status {
        case .placed:
            HStack(spacing: GagShapes.spacingM) {
                GagButton(title: "Accept", action: { Task { await viewModel.accept() } })
                GagButton(title: "Reject", style: .danger, action: { showRejectConfirm = true })
            }
        case .accepted:
            GagButton(title: "Start Preparing", action: { Task { await viewModel.startPreparing() } })
        case .preparing:
            GagButton(title: "Mark Ready", action: { Task { await viewModel.markReady() } })
        default:
            EmptyView()
        }
    }
}
