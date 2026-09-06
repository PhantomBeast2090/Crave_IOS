import SwiftUI

/// In-app notifications — backend feed + Realtime (mirrors Android
/// NotificationsScreen). Tapping an order notification marks it read and
/// deep-links to the order.
struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: NotificationsViewModel?
    @State private var selectedOrderId: String?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading notifications…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Notifications")
        .task { await setupViewModel() }
        .navigationDestination(item: $selectedOrderId) { orderId in
            OrderDetailView(orderId: orderId)
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = NotificationsViewModel(repository: appState.repository.notifications)
        self.viewModel = vm
        vm.start()
    }

    @ViewBuilder
    private func content(viewModel: NotificationsViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading notifications…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let items):
            if items.isEmpty {
                GagEmptyView(
                    icon: "bell",
                    title: "No notifications",
                    message: "Order updates will appear here in real time."
                )
                .padding(.top, 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: GagShapes.spacingS) {
                        ForEach(items) { notification in
                            NotificationCard(notification: notification) {
                                Task {
                                    if let orderId = await viewModel.open(notification) {
                                        selectedOrderId = orderId
                                    }
                                }
                            }
                        }
                    }
                    .padding(GagShapes.spacingL)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }
}

struct NotificationCard: View {
    let notification: AppNotification
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: GagShapes.spacingM) {
                Circle()
                    .fill(notification.isRead ? Color.clear : GagColors.brandOrange)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                Image(systemName: notification.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(GagColors.brandOrange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(notification.isRead ? GagTypography.titleSmall : GagTypography.titleSmall)
                        .fontWeight(notification.isRead ? .regular : .bold)
                        .foregroundStyle(GagColors.onSurface)
                    Text(notification.body)
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                    Text(Formatters.relativeTime(notification.createdAt))
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurfaceDim)
                }
                Spacer()
            }
            .padding(GagShapes.spacingM)
            .background(GagColors.surface)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { NotificationsView() }
        .environment(AppState())
}
