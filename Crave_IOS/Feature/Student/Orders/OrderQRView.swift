import SwiftUI

/// Pickup QR screen (mirrors Android PickupQRCodeScreen): renders the
/// backend `pickup_tokens.token_value` natively. Tokens expire 2h after
/// creation — the expiry is shown when the backend provides it.
struct OrderQRView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: OrderQRViewModel?
    let orderId: String

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading QR…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Pickup QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .task { await setupViewModel() }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = OrderQRViewModel(orderId: orderId, repository: appState.repository.orders)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: OrderQRViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading QR…")
        case .error(let message):
            VStack(spacing: GagShapes.spacingM) {
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 64))
                    .foregroundStyle(GagColors.error)
                Text(message)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.error)
                    .multilineTextAlignment(.center)
                GagButton(title: "Retry", action: { Task { await viewModel.retry() } })
            }
            .padding(GagShapes.spacingXL)
        case .loaded(let token, let expiresAt):
            VStack(spacing: GagShapes.spacingL) {
                Spacer()
                QRCodeView(content: token)
                    .padding(GagShapes.spacingL)
                    .background(.white)
                    .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                    .shadow(radius: 8)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(GagColors.success)
                Text("Show this QR to the outlet staff")
                    .font(GagTypography.titleMedium)
                    .foregroundStyle(GagColors.onSurface)
                if let expiresAt, !expiresAt.isEmpty {
                    Text("Valid until \(Formatters.relativeTime(expiresAt))")
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                } else {
                    Text("This QR code expires automatically")
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                Text(String(token.suffix(12)))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .padding(.horizontal, GagShapes.spacingM)
                    .padding(.vertical, GagShapes.spacingS)
                    .background(GagColors.surfaceVariant)
                    .clipShape(GagShapes.cornerRadius(GagShapes.radiusMedium))
                Spacer()
            }
            .padding(GagShapes.spacingL)
        }
    }
}
