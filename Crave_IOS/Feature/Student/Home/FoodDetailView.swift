import SwiftUI

struct FoodDetailView: View {
    let foodId: String
    let outletId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel: FoodDetailViewModel?
    @State private var quantity = 1
    @State private var selectedOptions: [String: CustomizationOption] = [:]
    @State private var showAddedToCart = false
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading…")
                    .task { await setupViewModel() }
            }
        }
    }
    
    private func setupViewModel() async {
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
                    foodImage(item)
                    foodInfo(item)
                    customizationsSection(item)
                    
                case .error(let message):
                    GagErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                    .frame(height: 300)
                }
            }
            .padding(.bottom, 120)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if case .loaded(let item) = viewModel?.state {
                bottomBar(item: item)
            }
        }
        .overlay(alignment: .bottom) {
            if showAddedToCart {
                addedToCartToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func foodImage(_ item: FoodItem) -> some View {
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
                Task { await viewModel?.toggleFavorite() }
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
                Label(item.category, systemImage: "tag")
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
        }
    }
    
    private func customizationsSection(_ item: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            if !item.customizations.isEmpty {
                Text("Customizations")
                    .font(GagTypography.titleMedium)
                    .foregroundStyle(GagColors.onSurface)
                    .padding(.horizontal, GagShapes.spacingL)
                
                ForEach(item.customizations) { customization in
                    CustomizationView(
                        customization: customization,
                        selectedOption: Binding(
                            get: { selectedOptions[customization.id] },
                            set: { selectedOptions[customization.id] = $0 }
                        )
                    )
                }
            }
        }
    }
    
    private func bottomBar(item: FoodItem) -> some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: GagShapes.spacingL) {
                Stepper(value: $quantity, in: 1...20) {
                    HStack {
                        Text("Qty")
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                        Text("\(quantity)")
                            .font(GagTypography.titleMedium)
                            .foregroundStyle(GagColors.onSurface)
                    }
                }
                .frame(width: 120)
                
                Spacer()
                
                let total = item.price * Double(quantity)
                Text(Formatters.price(total))
                    .font(GagTypography.titleLarge)
                    .foregroundStyle(GagColors.onSurface)
                
                GagButton(
                    title: item.isAvailable ? "Add to Cart" : "Unavailable",
                    isEnabled: item.isAvailable,
                    action: addToCart
                )
                .frame(width: 160)
            }
            .padding(.horizontal, GagShapes.spacingL)
            .padding(.vertical, GagShapes.spacingM)
            .background(GagColors.surface)
        }
    }
    
    private func addToCart() {
        // Add to cart logic will be implemented with CartViewModel
        withAnimation { showAddedToCart = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showAddedToCart = false }
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
    }
}

struct CustomizationView: View {
    let customization: FoodCustomization
    @Binding var selectedOption: CustomizationOption?
    
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
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: GagShapes.spacingS) {
                ForEach(customization.options) { option in
                    OptionChip(
                        option: option,
                        isSelected: selectedOption?.id == option.id,
                        action: { selectedOption = option }
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option.name)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(isSelected ? .white : GagColors.onSurface)
                if option.extraPrice > 0 {
                    Text("+\(Formatters.price(option.extraPrice))")
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : GagColors.brandOrange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GagShapes.spacingM)
            .background(isSelected ? GagColors.brandOrange : GagColors.surfaceVariant)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusMedium))
            .overlay(
                GagShapes.cornerRadius(GagShapes.radiusMedium)
                    .stroke(isSelected ? GagColors.brandOrange : GagColors.outlineVariant, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
