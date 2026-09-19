import SwiftUI

struct CartView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: CartViewModel?
    @State private var showCheckout = false
    @State private var slotSheetItem: CartItem?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading cart…")
            }
        }
        // `.task` on the outer Group so branch swaps can't cancel the load.
        .task { await setupViewModel() }
        .onDisappear { viewModel?.stop() }
        .navigationTitle("Cart")
        .sheet(isPresented: $showCheckout) {
            if let viewModel, let cart = viewModel.cart {
                CheckoutView(cart: cart)
            } else {
                // Narrow race (cart cleared between tap and sheet build):
                // loading fallback instead of a blank sheet.
                GagLoadingView(message: "Loading cart…")
            }
        }
        .sheet(item: $slotSheetItem) { item in
            slotPickerSheet(item, viewModel: viewModel)
        }
    }

    private func setupViewModel() async {
        if viewModel == nil {
            viewModel = CartViewModel(
                cart: appState.repository.cart,
                orders: appState.repository.orders
            )
        }
        // .task re-runs on reappear: resubscribe (start is idempotent).
        viewModel?.start()
    }

    @ViewBuilder
    private func content(viewModel: CartViewModel) -> some View {
        if viewModel.isEmpty {
            GagEmptyView(
                icon: "cart",
                title: "Your cart is empty",
                message: "Browse our outlets and add something delicious!"
            )
        } else if let cart = viewModel.cart {
            List {
                ForEach(cart.sections) { section in
                    Section {
                        outletHeader(section)
                        ForEach(section.items) { item in
                            CartItemRow(
                                item: item,
                                viewModel: viewModel,
                                matchMode: viewModel.matchMode,
                                selected: viewModel.selectedItemIds.contains(item.id),
                                onToggleSelect: { viewModel.toggleSelect(item) },
                                onPickSlot: { slotSheetItem = item }
                            )
                        }
                    }
                }

                Section {
                    VStack(spacing: GagShapes.spacingM) {
                        SummaryRow(label: "Subtotal", value: viewModel.subtotal)
                        SummaryRow(label: "GST (5%)", value: viewModel.tax)
                        Divider()
                        SummaryRow(label: "Total", value: viewModel.total, isTotal: true)
                        Text("Estimated prep time ~\(cart.estimatedPrepMinutes) minutes")
                            .font(GagTypography.labelSmall)
                            .foregroundStyle(GagColors.amber)
                    }
                    .padding(.vertical, GagShapes.spacingM)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .refreshable {
                await viewModel.sync()
                await viewModel.loadSlots()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        Task { await viewModel.clearCart() }
                    }
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.error)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar(viewModel: viewModel, cart: cart)
            }
        }
    }

    private func outletHeader(_ section: OutletCartSection) -> some View {
        HStack {
            Text(section.outletName.isEmpty ? "Outlet" : section.outletName)
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.brandOrange)
            Spacer()
            Text("\(section.totalItems) item" + (section.totalItems == 1 ? "" : "s"))
                .font(GagTypography.labelSmall)
                .foregroundStyle(GagColors.onSurfaceVariant)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func bottomBar(viewModel: CartViewModel, cart: Cart) -> some View {
        VStack(spacing: GagShapes.spacingS) {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.error)
            }
            if viewModel.matchMode {
                matchBar(viewModel: viewModel)
            } else {
                if cart.sections.count > 1 || (cart.items.count) > 1 {
                    Button("Match Slots") {
                        viewModel.enterMatchMode()
                    }
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.brandOrange)
                }
                GagButton(
                    title: "Proceed to Checkout (\(Formatters.price(viewModel.total)))",
                    accessibilityIdentifier: "proceedToCheckoutButton",
                    action: { showCheckout = true }
                )
            }
        }
        .padding(GagShapes.spacingL)
        .background(GagColors.surface)
    }

    @ViewBuilder
    private func matchBar(viewModel: CartViewModel) -> some View {
        VStack(spacing: GagShapes.spacingS) {
            if let matchError = viewModel.matchError {
                Text(matchError)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.error)
                    .multilineTextAlignment(.center)
            }
            if !viewModel.matchWindows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GagShapes.spacingS) {
                        ForEach(viewModel.matchWindows, id: \.displayTime) { window in
                            Button(window.displayTime) {
                                Task { await viewModel.applyMatch(window) }
                            }
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, GagShapes.spacingM)
                            .padding(.vertical, GagShapes.spacingS)
                            .background(GagColors.brandOrange)
                            .clipShape(GagShapes.cornerRadius(GagShapes.radiusPill))
                        }
                    }
                }
            }
            HStack {
                Button("Cancel") {
                    viewModel.exitMatchMode()
                }
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.onSurfaceVariant)
                Spacer()
                Text("\(viewModel.selectedItemIds.count) selected")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                Spacer()
                Button(viewModel.isMatching ? "Matching…" : "Match Slot") {
                    Task { await viewModel.computeMatches() }
                }
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.brandOrange)
                .disabled(viewModel.selectedItemIds.count < 2 || viewModel.isMatching)
            }
        }
    }

    @ViewBuilder
    private func slotPickerSheet(_ item: CartItem, viewModel: CartViewModel?) -> some View {
        NavigationStack {
            let slots = viewModel?.slotsByOutlet[item.outletId] ?? []
            List {
                if slots.isEmpty {
                    Text("No pickup slots for this outlet today.")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                } else {
                    ForEach(slots) { slot in
                        Button {
                            Task {
                                await viewModel?.setItemSlot(item, slotId: slot.id)
                                slotSheetItem = nil
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(slot.displayTime)
                                        .font(GagTypography.bodyMedium)
                                        .foregroundStyle(GagColors.onSurface)
                                    Text(slot.isSelectable
                                        ? "\(slot.availableCount) left"
                                        : "FULL")
                                        .font(GagTypography.labelSmall)
                                        .foregroundStyle(slot.isSelectable
                                            ? GagColors.onSurfaceVariant
                                            : GagColors.slotFull)
                                }
                                Spacer()
                                if item.slotId == slot.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(GagColors.brandOrange)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!slot.isSelectable)
                    }
                }
            }
            .navigationTitle("Pickup Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { slotSheetItem = nil }
                }
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let viewModel: CartViewModel
    var matchMode = false
    var selected = false
    var onToggleSelect: () -> Void = {}
    var onPickSlot: () -> Void = {}

    var body: some View {
        HStack(spacing: GagShapes.spacingM) {
            if matchMode {
                Button(action: onToggleSelect) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? GagColors.brandOrange : GagColors.outlineVariant)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selected ? "Deselect \(item.foodName)" : "Select \(item.foodName)")
            }
            Group {
                if let urlString = item.foodImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            itemPlaceholder
                        }
                    }
                } else {
                    itemPlaceholder
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusMedium))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    VegIndicator(isVeg: item.isVeg)
                    Text(item.foodName)
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurface)
                        .lineLimit(1)
                }

                ForEach(item.selectedCustomizations) { custom in
                    Text(customizationLabel(custom))
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }

                HStack(spacing: 4) {
                    Text("\(Formatters.price(item.price)) × \(item.quantity)")
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                    Text(Formatters.price(item.itemTotal))
                        .font(GagTypography.labelLarge)
                        .foregroundStyle(GagColors.brandOrange)
                }

                Button {
                    onPickSlot()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(slotLabel)
                            .font(GagTypography.labelSmall)
                    }
                    .foregroundStyle(GagColors.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose pickup slot for \(item.foodName)")
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    Task { await viewModel.removeItem(item) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(GagColors.error)
                }
                .buttonStyle(.plain)

                QuantitySelector(quantity: item.quantity, min: 1, max: CartMath.maxQuantity) { newValue in
                    Task { await viewModel.updateQuantity(item, quantity: newValue) }
                }
            }
        }
        .padding(.vertical, GagShapes.spacingS)
        .listRowBackground(GagColors.surface)
        .listRowSeparator(.hidden)
    }

    private var slotLabel: String {
        if let slot = viewModel.slot(for: item) {
            return slot.displayTime
        }
        return item.slotId == nil ? "Choose slot" : "Slot unavailable"
    }

    private func customizationLabel(_ custom: SelectedCustomization) -> String {
        if custom.extraPrice > 0 {
            return "\(custom.optionName) (+\(Formatters.price(custom.extraPrice)))"
        }
        return custom.optionName
    }

    private var itemPlaceholder: some View {
        ZStack {
            GagColors.surfaceVariant
            Image(systemName: "fork.knife")
                .foregroundStyle(GagColors.onSurfaceDim)
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: Double
    var isTotal: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? GagTypography.titleMedium : GagTypography.bodyMedium)
                .foregroundStyle(isTotal ? GagColors.onSurface : GagColors.onSurfaceVariant)
            Spacer()
            Text(Formatters.price(value))
                .font(isTotal ? GagTypography.titleMedium : GagTypography.bodyMedium)
                .foregroundStyle(GagColors.onSurface)
        }
    }
}
