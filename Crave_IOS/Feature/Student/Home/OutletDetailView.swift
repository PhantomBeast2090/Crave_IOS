import SwiftUI

struct OutletDetailView: View {
    let outletId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel: OutletDetailViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading outlet…")
            }
        }
        // NOTE: `.task` lives on the outer Group (not the else-branch) so that
        // assigning `viewModel` — which swaps the branch — doesn't cancel the
        // in-flight load with a CancellationError.
        .task { await setupViewModel() }
        .refreshable { await viewModel?.refresh() }
    }
    
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = OutletDetailViewModel(outletId: outletId, repository: appState.repository)
        self.viewModel = vm
        await vm.load()
    }
    
    @ViewBuilder
    private func content(viewModel: OutletDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                switch viewModel.state {
                case .idle, .loading:
                    GagLoadingView(message: "Loading menu…")
                        .frame(height: 300)
                    
                case .loaded(let outlet, let menu):
                    outletHeader(outlet)
                    menuSection(menu, outletId: outlet.id)
                    
                case .error(let message):
                    GagErrorView(message: message) {
                        Task { await viewModel.refresh() }
                    }
                    .frame(height: 300)
                }
            }
            .padding(.bottom, GagShapes.spacingXXL)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func outletHeader(_ outlet: Outlet) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlString = outlet.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            headerPlaceholder
                        }
                    }
                } else {
                    headerPlaceholder
                }
            }
            .frame(height: 200)
            .clipped()
            
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 200)
            
            VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                HStack {
                    Text(outlet.name)
                        .font(GagTypography.titleLarge)
                        .foregroundStyle(.white)
                    Spacer()
                    if outlet.isOpen {
                        Label("Open", systemImage: "circle.fill")
                            .font(GagTypography.labelSmall)
                            .foregroundStyle(GagColors.success)
                    } else {
                        Label("Closed", systemImage: "circle.fill")
                            .font(GagTypography.labelSmall)
                            .foregroundStyle(GagColors.error)
                    }
                }
                
                Text(outlet.description)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                
                HStack(spacing: GagShapes.spacingM) {
                    Label(outlet.location.building, systemImage: "location.fill")
                    if !outlet.location.floor.isEmpty {
                        Label("Floor \(outlet.location.floor)", systemImage: "building.2.fill")
                    }
                    if outlet.rating > 0 {
                        Label(String(format: "%.1f", outlet.rating), systemImage: "star.fill")
                            .foregroundStyle(GagColors.amber)
                    }
                }
                .font(GagTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(GagShapes.spacingL)
        }
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusXXLarge))
        .padding(.horizontal, GagShapes.spacingL)
    }
    
    private var headerPlaceholder: some View {
        ZStack {
            AppTheme.brandGradient
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
    
    private func menuSection(_ menu: [FoodItem], outletId: String) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            Text("Menu")
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.onSurface)
                .padding(.horizontal, GagShapes.spacingL)
            
            if menu.isEmpty {
                GagEmptyView(
                    icon: "fork.knife",
                    title: "No items available",
                    message: "This outlet doesn't have any items right now."
                )
                .padding(.horizontal, GagShapes.spacingL)
            } else {
                LazyVStack(spacing: GagShapes.spacingM) {
                    ForEach(menu) { item in
                        NavigationLink {
                            FoodDetailView(foodId: item.id, outletId: outletId)
                        } label: {
                            FoodItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, GagShapes.spacingL)
                    }
                }
            }
        }
    }
}
