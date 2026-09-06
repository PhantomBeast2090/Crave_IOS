import SwiftUI

struct FoodDetailView: View {
    let foodId: String
    let outletId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel: FoodDetailViewModel?
    @State private var quantity = 1
    /// variantId -> selected options (multi-select supported via maxSelections).
    @State private var selectedOptions: [String: [CustomizationOption]] = [:]
    @State private var showAddedToCart = false
    @State private var addError: String?
    @State private var isAdding = false
    @State private var pendingConflictAdd: PendingCartAdd?
    @State private var navigateToCart = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading…")
            }
        }
        // `.task` on the outer Group so branch swaps can't cancel the load.
        .task { await setupViewModel() }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = FoodDetailViewModel(foodId: foodId, repository: appState.repository)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: FoodDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                switch viewModel.state {
                case .idle, .loading:
                    GagLoadingView(message: "Loading…")
                        .frame(height: 300)

                case .loaded(let item):
                    foodImage(item, viewModel: viewModel)
                    foodInfo(item)
                    if !item.isAvailable {
                        Text("Currently Unavailable")
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.error)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, GagShapes.spacingM)
                            .background(GagColors.error.opacity(0.12))
                            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                            .padding(.horizontal, GagShapes.spacingL)
                    }
                    customizationsSection(item)

                case .error(let message):
                    GagErrorView(message: message) {
                        Task { await viewModel.refresh() }
                    }
                    .frame(height: 300)
                }
            }
            .padding(.bottom, 120)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Pushed detail screens hide the floating tab bar: besides matching
        // Android (no bottom nav on detail), this keeps the tab bar's hit
        // region from swallowing taps on the bottom action bar.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Cart must stay reachable from pushed screens (the tab bar is
            // hidden here), otherwise users can only reach it via Home.
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CartView()
                } label: {
                    Image(systemName: "cart")
                        .font(.system(size: 20))
                        .foregroundStyle(GagColors.onSurface)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detailCartButton")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if case .loaded(let item) = viewModel.state {
                bottomBar(item: item)
            }
        }
        .overlay(alignment: .bottom) {
            if showAddedToCart {
                addedToCartToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationDestination(isPresented: $navigateToCart) {
            CartView()
        }
        .alert("Different Outlet", isPresented: Binding(
            get: { pendingConflictAdd != nil },
            set: { if !$0 { pendingConflictAdd = nil } }
        )) {
            Button("Clear & Add", role: .destructive) {
                Task { await confirmConflictAdd() }
            }
            Button("Keep Cart", role: .cancel) {
                pendingConflictAdd = nil
            }
        } message: {
            Text("Your cart contains items from a different outlet. Clear cart and add from this outlet?")
        }
    }

    // MARK: - Customization logic (mirrors Android FoodDetailViewModel)

    private func selected(for variantId: String) -> [CustomizationOption] {
        selectedOptions[variantId] ?? []
    }

    private func toggleOption(variant: FoodCustomization, option: CustomizationOption) {
        var current = selectedOptions[variant.id] ?? []
        if let index = current.firstIndex(where: { $0.id == option.id }) {
            current.remove(at: index)
        } else if variant.maxSelections <= 1 {
            current = [option]
        } else if current.count < variant.maxSelections {
            current.append(option)
        } else {
            return // cap reached — extra taps are ignored (Android parity)
        }
        if current.isEmpty {
            selectedOptions.removeValue(forKey: variant.id)
        } else {
            selectedOptions[variant.id] = current
        }
    }

    private func canAddToCart(_ item: FoodItem) -> Bool {
        guard item.isAvailable else { return false }
        return missingRequiredNames(item).isEmpty
    }

    private func missingRequiredNames(_ item: FoodItem) -> [String] {
        item.customizations
            .filter { $0.isRequired && (selectedOptions[$0.id] ?? []).isEmpty }
            .map { $0.name }
    }

    private func computedPrice(_ item: FoodItem) -> Double {
        let extras = selectedOptions.values.flatMap { $0 }.reduce(0) { $0 + $1.extraPrice }
        return item.price + extras
    }

    private func selectedCustomizations(_ item: FoodItem) -> [SelectedCustomization] {
        item.customizations.flatMap { variant in
            (selectedOptions[variant.id] ?? []).map { option in
                SelectedCustomization(
                    customizationId: variant.id,
                    customizationName: variant.name,
                    optionId: option.id,
                    optionName: option.name,
                    extraPrice: option.extraPrice
                )
            }
        }
    }

    // MARK: - Add to cart

    private func addToCart(_ item: FoodItem) {
        guard canAddToCart(item), !isAdding else { return }
        isAdding = true
        addError = nil
        Task {
            defer { isAdding = false }
            do {
                _ = try await appState.repository.cart.addItem(
                    foodItem: item,
                    outletName: item.outletName,
                    quantity: quantity,
                    customizations: selectedCustomizations(item),
                    specialInstructions: nil
                )
                withAnimation { showAddedToCart = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showAddedToCart = false }
                    navigateToCart = true
                }
            } catch let cartError as CartError {
                if case .outletConflict = cartError {
                    pendingConflictAdd = PendingCartAdd(
                        foodItem: item,
                        outletName: item.outletName,
                        quantity: quantity,
                        customizations: selectedCustomizations(item),
                        specialInstructions: nil
                    )
                } else {
                    addError = cartError.localizedDescription
                }
            } catch is CancellationError {
            } catch {
                addError = error.localizedDescription
            }
        }
    }

    private func confirmConflictAdd() async {
        guard let pending = pendingConflictAdd else { return }
        pendingConflictAdd = nil
        do {
            try await appState.repository.cart.clearCart()
            _ = try await appState.repository.cart.addItem(
                foodItem: pending.foodItem,
                outletName: pending.outletName,
                quantity: pending.quantity,
                customizations: pending.customizations,
                specialInstructions: pending.specialInstructions
            )
            // Same post-add behavior as the direct path: toast, then Cart.
            withAnimation { showAddedToCart = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showAddedToCart = false }
                navigateToCart = true
            }
        } catch is CancellationError {
        } catch {
            addError = error.localizedDescription
        }
    }

    // MARK: - Sections

    private func foodImage(_ item: FoodItem, viewModel: FoodDetailViewModel) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            imagePlaceholder
                        }
                    }
                } else {
                    imagePlaceholder
                }
            }
            .frame(height: 240)
            .clipped()

            Button {
                Task { await viewModel.toggleFavorite() }
            } label: {
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isFavorite ? GagColors.error : .white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.3))
                    .clipShape(Circle())
                    .padding(GagShapes.spacingM)
            }
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            GagColors.surfaceVariant
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(GagColors.onSurfaceDim)
        }
    }

    private func foodInfo(_ item: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        VegIndicator(isVeg: item.isVeg)
                        Text(item.name)
                            .font(GagTypography.titleLarge)
                            .foregroundStyle(GagColors.onSurface)
                    }

                    Text(item.outletName)
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.brandOrange)
                }

                Spacer()

                Text(Formatters.price(item.price))
                    .font(GagTypography.titleMedium)
                    .foregroundStyle(GagColors.onSurface)
            }
            .padding(.horizontal, GagShapes.spacingL)

            if !item.description.isEmpty {
                Text(item.description)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .padding(.horizontal, GagShapes.spacingL)
            }

            HStack(spacing: GagShapes.spacingL) {
                Label("\(item.prepTimeMinutes) min", systemImage: "clock")
                if item.rating > 0 {
                    Label(String(format: "%.1f", item.rating), systemImage: "star.fill")
                        .foregroundStyle(GagColors.amber)
                }
                if !item.category.isEmpty {
                    Label(item.category, systemImage: "tag")
                }
            }
            .font(GagTypography.labelMedium)
            .foregroundStyle(GagColors.onSurfaceVariant)
            .padding(.horizontal, GagShapes.spacingL)

            Divider()
                .padding(.horizontal, GagShapes.spacingL)

            if !item.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingredients")
                        .font(GagTypography.labelLarge)
                        .foregroundStyle(GagColors.onSurface)
                    Text(item.ingredients.joined(separator: ", "))
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                .padding(.horizontal, GagShapes.spacingL)
            }

            if let calories = item.calories {
                Text("~\(calories) cal")
                    .font(GagTypography.labelSmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .padding(.horizontal, GagShapes.spacingL)
            }
        }
    }

    private func customizationsSection(_ item: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            if !item.customizations.isEmpty {
                ForEach(item.customizations) { customization in
                    CustomizationView(
                        customization: customization,
                        selected: selected(for: customization.id),
                        onToggle: { toggleOption(variant: customization, option: $0) }
                    )
                }
            }
        }
    }

    private func bottomBar(item: FoodItem) -> some View {
        VStack(spacing: GagShapes.spacingS) {
            if let addError {
                Text(addError)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.error)
            } else if item.isAvailable, !canAddToCart(item) {
                // Explain exactly what is still missing (Android parity:
                // the button stays disabled until required groups are filled).
                Text("Select Required: \(missingRequiredNames(item).joined(separator: ", "))")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.amber)
            }
            VStack(spacing: GagShapes.spacingS) {
                Divider()

                // Row 1: quantity + single-line total (never wraps).
                HStack {
                    HStack(spacing: GagShapes.spacingS) {
                        Text("Qty")
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                        QuantitySelector(quantity: quantity, min: 1, max: CartMath.maxQuantity) {
                            quantity = $0
                        }
                    }

                    Spacer(minLength: GagShapes.spacingM)

                    let total = computedPrice(item) * Double(quantity)
                    Text(Formatters.price(total))
                        .font(GagTypography.titleMedium)
                        .foregroundStyle(GagColors.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                // Row 2: full-width action (largest touch target, no crowding).
                GagButton(
                    title: "Add to Cart",
                    isLoading: isAdding,
                    isEnabled: canAddToCart(item),
                    accessibilityIdentifier: "addToCartButton",
                    action: { addToCart(item) }
                )
            }
            .padding(.horizontal, GagShapes.spacingL)
            .padding(.vertical, GagShapes.spacingM)
            .background(GagColors.surface)
        }
    }

    private var addedToCartToast: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(GagColors.success)
            Text("Added to cart")
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.onSurface)
        }
        .padding(.horizontal, GagShapes.spacingXL)
        .padding(.vertical, GagShapes.spacingM)
        .background(GagColors.surface)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
        .shadow(radius: 10)
        .padding(.bottom, 100)
        .accessibilityIdentifier("addedToCartToast")
    }
}

struct CustomizationView: View {
    let customization: FoodCustomization
    let selected: [CustomizationOption]
    let onToggle: (CustomizationOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            HStack {
                Text(customization.name)
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.onSurface)
                if customization.isRequired {
                    Text("Required")
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(GagColors.amber.opacity(0.12))
                        .clipShape(GagShapes.cornerRadius(GagShapes.radiusSmall))
                }
            }
            .padding(.horizontal, GagShapes.spacingL)

            if customization.maxSelections > 1 {
                Text("Select up to \(customization.maxSelections)")
                    .font(GagTypography.labelSmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .padding(.horizontal, GagShapes.spacingL)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: GagShapes.spacingS) {
                ForEach(customization.options) { option in
                    OptionChip(
                        option: option,
                        isSelected: selected.contains(where: { $0.id == option.id }),
                        isSingleSelect: customization.maxSelections <= 1,
                        action: { onToggle(option) }
                    )
                }
            }
            .padding(.horizontal, GagShapes.spacingL)
        }
    }
}

struct OptionChip: View {
    let option: CustomizationOption
    let isSelected: Bool
    let isSingleSelect: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSingleSelect
                    ? (isSelected ? "largecircle.fill.circle" : "circle")
                    : (isSelected ? "checkmark.square.fill" : "square"))
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? GagColors.brandOrange : GagColors.onSurfaceDim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.onSurface)
                    if option.extraPrice > 0 {
                        Text("+\(Formatters.price(option.extraPrice))")
                            .font(GagTypography.labelSmall)
                            .foregroundStyle(GagColors.brandOrange)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagShapes.spacingM)
            .padding(.horizontal, GagShapes.spacingM)
            .background(isSelected ? GagColors.brandOrange.opacity(0.12) : GagColors.surfaceVariant)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusMedium))
            .overlay(
                GagShapes.cornerRadius(GagShapes.radiusMedium)
                    .stroke(isSelected ? GagColors.brandOrange : GagColors.outlineVariant, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("optionChip")
    }
}
