import SwiftUI

struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: CheckoutViewModel?
    @State private var showTracking = false
    @State private var showQR = false
    @State private var successOrder: Order?

    let cart: Cart

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    checkoutContent(viewModel: viewModel)
                } else {
                    GagLoadingView(message: "Preparing checkout…")
                }
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await setupViewModel() }
            .navigationDestination(isPresented: $showTracking) {
                if let successOrder {
                    OrderTrackingView(orderId: successOrder.id)
                }
            }
            .sheet(isPresented: $showQR) {
                if let successOrder {
                    NavigationStack { OrderQRView(orderId: successOrder.id) }
                }
            }
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = CheckoutViewModel(
            cart: cart,
            repository: appState.repository,
            userEmail: appState.currentUser?.email
        )
        self.viewModel = vm
        await vm.loadSlots()
    }

    @ViewBuilder
    private func checkoutContent(viewModel: CheckoutViewModel) -> some View {
        switch viewModel.flowState {
        case .success(let order):
            confirmationContent(order: order)
        default:
            checkoutForm(viewModel: viewModel)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func checkoutForm(viewModel: CheckoutViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                orderSummarySection
                pickupSlotSection(viewModel: viewModel)
                paymentMethodSection(viewModel: viewModel)
                flowStatusSection(viewModel: viewModel)

                let placing: Bool = {
                    if case .placing = viewModel.flowState { return true }
                    if case .verifying = viewModel.flowState { return true }
                    if case .awaitingPayment = viewModel.flowState { return true }
                    return false
                }()
                GagButton(
                    title: viewModel.selectedSlot == nil ? "Select a Pickup Slot First" : "Place Order",
                    isLoading: placing,
                    isEnabled: viewModel.canPlaceOrder,
                    action: { Task { await viewModel.placeOrder() } }
                )
            }
            .padding(GagShapes.spacingL)
        }
    }

    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            Text("Order Summary")
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)

            Text("Ordering from \(cart.outletName)")
                .font(GagTypography.labelMedium)
                .foregroundStyle(GagColors.brandOrange)

            ForEach(cart.items) { item in
                HStack {
                    Text("\(item.foodName) × \(item.quantity)")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurface)
                    Spacer()
                    Text(Formatters.price(item.itemTotal))
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurface)
                }
                if !item.selectedCustomizations.isEmpty {
                    Text(item.selectedCustomizations.map { $0.optionName }.joined(separator: ", "))
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
            }

            Divider()
            SummaryRow(label: "Subtotal", value: cart.subtotal)
            SummaryRow(label: "GST (5%)", value: cart.tax)
            Divider()
            SummaryRow(label: "Total", value: cart.total, isTotal: true)
        }
        .gagCard()
    }

    @ViewBuilder
    private func pickupSlotSection(viewModel: CheckoutViewModel) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            Text("Pickup Slot")
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)

            switch viewModel.slotsState {
            case .idle, .loading:
                HStack {
                    ProgressView()
                        .tint(GagColors.brandOrange)
                    Text("Loading slots…")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, GagShapes.spacingL)

            case .empty:
                Text("No pickup slots available for this outlet today.")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)

            case .error(let message):
                VStack(spacing: GagShapes.spacingS) {
                    Text(message)
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.error)
                    Button("Retry") {
                        Task { await viewModel.retrySlots() }
                    }
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.brandOrange)
                }

            case .loaded(let slots):
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: GagShapes.spacingS) {
                    ForEach(slots) { slot in
                        PickupSlotRow(
                            slot: slot,
                            isSelected: viewModel.selectedSlot?.id == slot.id,
                            action: {
                                if slot.isSelectable { viewModel.selectedSlot = slot }
                            }
                        )
                    }
                }
            }
        }
        .gagCard()
    }

    private func paymentMethodSection(viewModel: CheckoutViewModel) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            Text("Payment Method")
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)

            ForEach(PaymentMethod.allCases, id: \.self) { method in
                Button {
                    viewModel.paymentMethod = method
                } label: {
                    HStack(spacing: GagShapes.spacingM) {
                        Image(systemName: viewModel.paymentMethod == method
                            ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(viewModel.paymentMethod == method
                                ? GagColors.brandOrange : GagColors.outlineVariant)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(method.displayName)
                                .font(GagTypography.bodyMedium)
                                .foregroundStyle(GagColors.onSurface)
                            Text(method == .online ? "Pay securely via Razorpay" : "Pay when you pick up")
                                .font(GagTypography.labelSmall)
                                .foregroundStyle(GagColors.onSurfaceVariant)
                        }
                        Spacer()
                    }
                    .padding(GagShapes.spacingM)
                    .background(GagColors.surfaceVariant)
                    .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                }
                .buttonStyle(.plain)
            }
        }
        .gagCard()
    }

    @ViewBuilder
    private func flowStatusSection(viewModel: CheckoutViewModel) -> some View {
        switch viewModel.flowState {
        case .error(let message):
            VStack(spacing: GagShapes.spacingS) {
                Text(message)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.error)
                Button("Try Again") {
                    Task { await viewModel.retryAfterError() }
                }
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.brandOrange)
            }
        case .paymentCancelled(let orderId):
            VStack(spacing: GagShapes.spacingS) {
                Text("Payment was cancelled. Your order is kept and your cart is intact — you can retry payment.")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.amber)
                Button("Retry Payment") {
                    Task { await viewModel.retryAfterError() }
                }
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.brandOrange)
                Text("Order: \(orderId.prefix(8))…")
                    .font(GagTypography.labelSmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
        case .awaitingPayment:
            HStack {
                ProgressView().tint(GagColors.brandOrange)
                Text("Waiting for payment…")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
        case .verifying:
            HStack {
                ProgressView().tint(GagColors.brandOrange)
                Text("Verifying payment…")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Confirmation (mirrors Android OrderConfirmation)

    private func confirmationContent(order: Order) -> some View {
        ScrollView {
            VStack(spacing: GagShapes.spacingL) {
                VStack(spacing: GagShapes.spacingM) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(GagColors.success)
                    Text("Order Placed!")
                        .font(GagTypography.titleLarge)
                        .foregroundStyle(GagColors.onSurface)
                    Text("Order \(order.orderNumber)")
                        .font(GagTypography.titleMedium)
                        .foregroundStyle(GagColors.brandOrange)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, GagShapes.spacingXL)

                VStack(spacing: GagShapes.spacingS) {
                    if let slot = order.pickupSlot {
                        confirmationRow("Pickup", slot.displayTime)
                    }
                    confirmationRow("Total", Formatters.price(order.total))
                    confirmationRow("Payment", order.paymentMethod.displayName)
                    confirmationRow("Status", order.status.displayName)
                }
                .gagCard()

                Text("You'll receive a notification when it's ready for pickup.")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)

                GagButton(title: "Track Order", action: {
                    successOrder = order
                    showTracking = true
                })
                GagButton(title: "Show Pickup QR", style: .secondary, action: {
                    successOrder = order
                    showQR = true
                })
                Button("Done") { dismiss() }
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            .padding(GagShapes.spacingL)
        }
    }

    private func confirmationRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(GagTypography.bodyMedium)
                .foregroundStyle(GagColors.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(GagTypography.bodyMedium)
                .foregroundStyle(GagColors.onSurface)
        }
    }
}

struct PickupSlotRow: View {
    let slot: PickupSlot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.displayTime)
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.onSurface)
                if slot.status == .full {
                    Text("FULL")
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.slotFull)
                } else {
                    Text("\(slot.availableCount) left")
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GagShapes.spacingM)
            .background(isSelected ? GagColors.brandOrange.opacity(0.15) : GagColors.surface)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
            .overlay(
                GagShapes.cornerRadius(GagShapes.radiusLarge)
                    .stroke(isSelected ? GagColors.brandOrange : GagColors.outlineVariant, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!slot.isSelectable)
        .opacity(slot.isSelectable ? 1 : 0.5)
    }
}
