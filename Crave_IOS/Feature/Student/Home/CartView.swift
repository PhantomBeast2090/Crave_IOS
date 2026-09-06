import SwiftUI

struct CartView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: CartViewModel?
    @State private var showCheckout = false

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
        .navigationTitle("Cart")
        .sheet(isPresented: $showCheckout) {
            if let viewModel, let cart = viewModel.cart {
                CheckoutView(cart: cart)
            }
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = CartViewModel(repository: appState.repository.cart)
        self.viewModel = vm
        vm.start()
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
                Section {
                    HStack {
                        Text("Ordering from:")
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                        Text(cart.outletName)
                            .font(GagTypography.titleSmall)
                            .foregroundStyle(GagColors.brandOrange)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ForEach(cart.items) { item in
                    CartItemRow(item: item, viewModel: viewModel)
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
                do { try await appState.repository.cart.syncFromBackend() } catch { }
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
                VStack(spacing: GagShapes.spacingS) {
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.error)
                    }
                    GagButton(
                        title: "Proceed to Checkout (\(Formatters.price(viewModel.total)))",
                        action: { showCheckout = true }
                    )
                }
                .padding(GagShapes.spacingL)
                .background(GagColors.surface)
            }
            .alert("Different Outlet", isPresented: Binding(
                get: { viewModel.pendingConflict != nil },
                set: { if !$0 { viewModel.dismissConflict() } }
            )) {
                Button("Clear & Add", role: .destructive) {
                    Task { await viewModel.confirmConflictAdd() }
                }
                Button("Keep Cart", role: .cancel) {
                    viewModel.dismissConflict()
                }
            } message: {
                Text("Your cart contains items from a different outlet. Clear cart and add from this outlet?")
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let viewModel: CartViewModel

    var body: some View {
        HStack(spacing: GagShapes.spacingM) {
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
                HStack {
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

                Stepper(
                    "",
                    value: Binding(
                        get: { item.quantity },
                        set: { newValue in Task { await viewModel.updateQuantity(item, quantity: newValue) } }
                    ),
                    in: 1...CartMath.maxQuantity
                )
                .labelsHidden()
            }
        }
        .padding(.vertical, GagShapes.spacingS)
        .listRowBackground(GagColors.surface)
        .listRowSeparator(.hidden)
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
