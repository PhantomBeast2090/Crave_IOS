import SwiftUI

/// Vendor dashboard (mirrors Android VendorDashboardScreen): pending/
/// preparing/ready stats, incoming orders with per-status actions, scan FAB.
struct VendorDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: VendorDashboardViewModel?
    @State private var showScanner = false
    @State private var rejectOrder: Order?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading dashboard…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Vendor Dashboard")
        .task { await setupViewModel() }
        .sheet(isPresented: $showScanner) {
            NavigationStack { VendorScannerView() }
        }
        .confirmationDialog("Reject this order?", isPresented: Binding(
            get: { rejectOrder != nil },
            set: { if !$0 { rejectOrder = nil } }
        ), titleVisibility: .visible) {
            Button("Reject Order", role: .destructive) {
                if let order = rejectOrder {
                    Task { await viewModel?.reject(order) }
                }
            }
            Button("Keep Order", role: .cancel) {}
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = VendorDashboardViewModel(repository: appState.repository.orders)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: VendorDashboardViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading dashboard…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded:
            dashboardContent(viewModel: viewModel)
        }
    }

    private func dashboardContent(viewModel: VendorDashboardViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                HStack(spacing: GagShapes.spacingM) {
                    VendorStatCard(title: "Pending", count: viewModel.pendingCount, color: GagColors.info)
                    VendorStatCard(title: "Preparing", count: viewModel.preparingCount, color: GagColors.amber)
                    VendorStatCard(title: "Ready", count: viewModel.readyCount, color: GagColors.success)
                }

                if let actionError = viewModel.actionError {
                    Text(actionError)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.error)
                }

                Text("Incoming Orders")
                    .font(GagTypography.titleSmall)
                    .foregroundStyle(GagColors.onSurface)

                if viewModel.activeOrders.isEmpty {
                    Text("No active orders right now 🎉")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, GagShapes.spacingXL)
                } else {
                    LazyVStack(spacing: GagShapes.spacingM) {
                        ForEach(viewModel.activeOrders) { order in
                            NavigationLink {
                                VendorOrderDetailView(orderId: order.id)
                            } label: {
                                VendorOrderCard(order: order, viewModel: viewModel) {
                                    rejectOrder = order
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(GagShapes.spacingL)
        }
        .refreshable { await viewModel.refresh() }
        .safeAreaInset(edge: .bottom) {
            GagButton(title: "Scan Pickup", action: { showScanner = true })
                .padding(GagShapes.spacingL)
                .background(GagColors.surface)
        }
    }
}

struct VendorStatCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(GagTypography.titleLarge)
                .foregroundStyle(color)
            Text(title)
                .font(GagTypography.labelSmall)
                .foregroundStyle(GagColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GagShapes.spacingM)
        .background(color.opacity(0.12))
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }
}

/// Order card with legal status actions only (mirrors Android's per-status buttons).
struct VendorOrderCard: View {
    let order: Order
    let viewModel: VendorDashboardViewModel
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            HStack {
                Text(order.orderNumber)
                    .font(GagTypography.titleSmall)
                    .foregroundStyle(GagColors.onSurface)
                Spacer()
                OrderStatusBadge(status: order.status)
            }

            Text("\(order.items.reduce(0) { $0 + $1.quantity }) item(s) · \(Formatters.price(order.total))")
                .font(GagTypography.bodySmall)
                .foregroundStyle(GagColors.onSurfaceVariant)

            if let slot = order.pickupSlot {
                Label("Pickup: \(slot.displayTime)", systemImage: "clock")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.info)
            }

            if viewModel.actionOrderId == order.id {
                HStack {
                    ProgressView().tint(GagColors.brandOrange)
                    Text("Updating…")
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
            } else {
                vendorActions
            }
        }
        .padding(GagShapes.spacingM)
        .background(GagColors.surface)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }

    @ViewBuilder
    private var vendorActions: some View {
        switch order.status {
        case .placed:
            HStack(spacing: GagShapes.spacingM) {
                GagButton(title: "Accept", style: .primary, action: {
                    Task { await viewModel.accept(order) }
                })
                GagButton(title: "Reject", style: .danger, action: onReject)
            }
        case .accepted:
            GagButton(title: "Start Preparing", action: {
                Task { await viewModel.startPreparing(order) }
            })
        case .preparing:
            GagButton(title: "Mark Ready", action: {
                Task { await viewModel.markReady(order) }
            })
        default:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack { VendorDashboardView() }
        .environment(AppState())
}
