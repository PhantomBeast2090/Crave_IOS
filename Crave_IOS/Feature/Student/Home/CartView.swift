import SwiftUI
import SwiftData

struct CartView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var viewModel: CartViewModel?
    @State private var showCheckout = false
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading cart…")
                    .task { viewModel = CartViewModel(modelContext: modelContext) }
            }
        }
        .navigationTitle("Cart")
        .sheet(isPresented: $showCheckout) {
            CheckoutView()
                .environment(viewModel!)
        }
    }
    
    @ViewBuilder
    private func content(viewModel: CartViewModel) -> some View {
        if viewModel.isEmpty {
            GagEmptyView(
                icon: "cart",
                title: "Your cart is empty",
                message: "Add some delicious food to get started!",
                actionTitle: "Browse Outlets",
                action: { appState.phase = .main(.student) }
            )
        } else {
            List {
                ForEach(viewModel.items) { item in
                    CartItemRow(item: item, viewModel: viewModel)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.removeItem(viewModel.items[index])
                    }
                }
                
                Section {
                    VStack(spacing: GagShapes.spacingM) {
                        SummaryRow(label: "Subtotal", value: viewModel.subtotal)
                        SummaryRow(label: "Tax (5%)", value: viewModel.tax)
                        Divider()
                        SummaryRow(label: "Total", value: viewModel.total, isTotal: true)
                    }
                    .padding(.vertical, GagShapes.spacingM)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .safeAreaInset(edge: .bottom) {
                if !viewModel.isEmpty {
                    GagButton(
                        title: "Proceed to Checkout (\(Formatters.price(viewModel.total)))",
                        action: { showCheckout = true }
                    )
                    .padding(GagShapes.spacingL)
                    .background(GagColors.surface)
                }
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItemEntity
    @ObservedObject var viewModel: CartViewModel
    
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
                
                if !item.customizationNames.isEmpty {
                    Text(item.customizationNames.joined(separator: ", "))
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                
                Text(Formatters.price(item.unitPrice))
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurface)
            }
            
            Spacer()
            
            Stepper(
                "",
                value: Binding(
                    get: { item.quantity },
                    set: { viewModel.updateQuantity(item, quantity: $0) }
                ),
                in: 1...20
            )
            .labelsHidden()
        }
        .padding(.vertical, GagShapes.spacingS)
        .listRowBackground(GagColors.surface)
        .listRowSeparator(.hidden)
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
