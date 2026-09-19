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
                } else {
                    GagLoadingView(message: "Loading order…")
                }
            }
            .sheet(isPresented: $showQR) {
                if let successOrder {
                    NavigationStack { OrderQRView(orderId: successOrder.id) }
                } else {
                    GagLoadingView(message: "Loading order…")
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
        case .success:
            confirmationContent(orders: viewModel.completedOrders)
                .sensoryFeedback(.success, trigger: viewModel.completedOrders.count)
        default:
            checkoutForm(viewModel: viewModel)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func checkoutForm(viewModel: CheckoutViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                ForEach(viewModel.sections) { section in
                    sectionCard(section, viewModel: viewModel)
                }
                orderTotalsSection
                paymentMethodSection(viewModel: viewModel)
                flowStatusSection(viewModel: viewModel)

                let placing: Bool = {
                    if case .placing = viewModel.flowState { return true }
                    if case .verifying = viewModel.flowState { return true }
                    if case .awaitingPayment = viewModel.flowState { return true }
                    return false
                }()
                let missingSlots = viewModel.sections.contains { $0.selectedSlot == nil }
                GagButton(
                    title: missingSlots ? "Select a Pickup Slot for Each Outlet" : "Place Order",
                    isLoading: placing,
                    isEnabled: viewModel.canPlaceOrder,
                    accessibilityIdentifier: "placeOrderButton",
                    action: { Task { await viewModel.placeOrder() } }
                )
            }
            .padding(GagShapes.spacingL)
        }
    }

    private func sectionCard(_ section: CheckoutViewModel.CheckoutSection, viewModel: CheckoutViewModel) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            Text(section.outletName)
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)

            ForEach(section.items) { item in
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
            SummaryRow(label: "Subtotal", value: section.subtotal)

            Text("Pickup Slot · \(section.outletName)")
                .font(GagTypography.labelMedium)
                .foregroundStyle(GagColors.onSurfaceVariant)
                .padding(.top, GagShapes.spacingS)

            sectionSlots(section, viewModel: viewModel)
        }
        .gagCard()
    }

    @ViewBuilder
    private func sectionSlots(_ section: CheckoutViewModel.CheckoutSection, viewModel: CheckoutViewModel) -> some View {
        switch section.slotsState {
        case .idle, .loading:
            HStack {
                ProgressView()
                    .tint(GagColors.brandOrange)
                Text("Loading slots…")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagShapes.spacingM)

        case .empty:
            VStack(spacing: GagShapes.spacingS) {
                Text("No pickup slots available for this outlet today.")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                Button("Check Again") {
                    Task { await viewModel.retrySlots(outletId: section.outletId) }
                }
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.brandOrange)
            }

        case .error(let message):
            VStack(spacing: GagShapes.spacingS) {
                Text(message)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.error)
                Button("Retry") {
                    Task { await viewModel.retrySlots(outletId: section.outletId) }
                }
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.brandOrange)
            }

        case .loaded(let slots):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: GagShapes.spacingS) {
                ForEach(slots) { slot in
                    PickupSlotRow(
                        slot: slot,
                        isSelected: section.selectedSlot?.id == slot.id,
                        action: {
                            if slot.isSelectable {
                                Task { await viewModel.selectSlot(outletId: section.outletId, slot: slot) }
                            }
                        }
                    )
                }
            }
        }
    }

    private var orderTotalsSection: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            Text("Order Total")
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)
            Divider()
            SummaryRow(label: "Subtotal", value: cart.subtotal)
            SummaryRow(label: "GST (5%)", value: cart.tax)
            Divider()
            SummaryRow(label: "Total", value: cart.total, isTotal: true)
        }
        .gagCard()
    }

    private func paymentMethodSection(viewModel: CheckoutViewModel) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            Text("Payment Method")
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)

            // ONLINE only (product decision): the backend still supports
            // PAY_AT_COUNTER, but the student UI no longer offers it.
            HStack(spacing: GagShapes.spacingM) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(GagColors.brandOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(PaymentMethod.online.displayName)
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurface)
                    Text("Pay securely via Razorpay")
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                Spacer()
            }
            .padding(GagShapes.spacingM)
            .background(GagColors.surfaceVariant)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Payment method: Online Payment. Pay securely via Razorpay.")
            .accessibilityIdentifier("onlinePaymentRow")
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
            VStack(spacing: GagShapes.spacingS) {
                HStack {
                    ProgressView().tint(GagColors.brandOrange)
                    Text("Waiting for payment…")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                // Escape hatch: the native sheet can be killed without a
                // callback (backgrounding, OS reclaim). Cancelling keeps the
                // order and cart intact for a later retry.
                Button("Cancel Payment") {
                    viewModel.cancelAwaitingPayment()
                }
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.brandOrange)
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

    private func confirmationContent(orders: [Order]) -> some View {
        ScrollView {
            VStack(spacing: GagShapes.spacingL) {
                VStack(spacing: GagShapes.spacingM) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(GagColors.success)
                    Text(orders.count > 1 ? "Orders Placed!" : "Order Placed!")
                        .font(GagTypography.titleLarge)
                        .foregroundStyle(GagColors.onSurface)
                    Text("Campus Checkout · \(orders.count) order" + (orders.count == 1 ? "" : "s"))
                        .font(GagTypography.titleMedium)
                        .foregroundStyle(GagColors.brandOrange)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, GagShapes.spacingXL)

                ForEach(orders) { order in
                    VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                        Text(order.outletName)
                            .font(GagTypography.titleSmall)
                            .foregroundStyle(GagColors.onSurface)
                        Text("Order \(order.orderNumber)")
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.brandOrange)
                        if let slot = order.pickupSlot {
                            confirmationRow("Pickup", slot.displayTime)
                        }
                        confirmationRow("Total", Formatters.price(order.total))
                        confirmationRow("Payment", order.paymentMethod.displayName)
                        confirmationRow("Status", order.status.displayName)

                        HStack(spacing: GagShapes.spacingM) {
                            Button("Track") {
                                successOrder = order
                                showTracking = true
                            }
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.brandOrange)
                            Spacer()
                            Button("Pickup QR") {
                                successOrder = order
                                showQR = true
                            }
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.brandOrange)
                        }
                        .padding(.top, GagShapes.spacingS)
                    }
                    .gagCard()
                }

                Text("You'll receive a notification when it's ready for pickup.")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)

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
        .accessibilityIdentifier("pickupSlotRow")
        .disabled(!slot.isSelectable)
        .opacity(slot.isSelectable ? 1 : 0.5)
    }
}
