import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading…")
                    .task { await setupViewModel() }
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !appState.isBackendConfigured {
                    Image(systemName: "key.slash")
                        .foregroundStyle(GagColors.amber)
                }
            }
        }
        .refreshable { await viewModel?.refresh() }
    }
    
    private func setupViewModel() async {
        let vm = HomeViewModel(repository: appState.repository)
        self.viewModel = vm
        await vm.load()
    }
    
    @ViewBuilder
    private func content(viewModel: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                heroHeader
                
                if !appState.isBackendConfigured {
                    GagNotConfiguredBanner()
                        .padding(.horizontal, GagShapes.spacingL)
                }
                
                switch viewModel.state {
                case .idle, .loading:
                    GagLoadingView(message: "Fetching outlets…")
                        .frame(height: 220)
                        .padding(.horizontal, GagShapes.spacingL)
                    
                case .loaded(let outlets, let categories):
                    categoriesSection(categories)
                    outletsSection(outlets)
                    
                case .error(let message):
                    GagErrorView(message: message) {
                        Task { await viewModel.refresh() }
                    }
                    .frame(height: 220)
                    .padding(.horizontal, GagShapes.spacingL)
                }
            }
            .padding(.vertical, GagShapes.spacingM)
        }
        .background(AppTheme.screenBackground)
    }
    
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: GagShapes.radiusXXLarge, style: .continuous)
                .fill(AppTheme.brandGradient)
                .frame(height: 160)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hi there 👋")
                    .font(GagTypography.titleLarge)
                    .foregroundStyle(.white)
                Text("Order ahead from campus outlets and skip the queue.")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(GagShapes.spacingXL)
        }
        .padding(.horizontal, GagShapes.spacingL)
    }
    
    private func categoriesSection(_ categories: [FoodCategory]) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            SectionHeader(title: "Categories", icon: "square.grid.2x2")
                .padding(.horizontal, GagShapes.spacingL)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GagShapes.spacingS) {
                    ForEach(categories) { category in
                        CategoryChip(category: category)
                    }
                }
                .padding(.horizontal, GagShapes.spacingL)
            }
        }
    }
    
    private func outletsSection(_ outlets: [Outlet]) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            SectionHeader(title: "Outlets near you", icon: "storefront")
                .padding(.horizontal, GagShapes.spacingL)
            
            if outlets.isEmpty {
                GagEmptyView(
                    icon: "shippingbox",
                    title: "No outlets yet",
                    message: "Check back later or contact support."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GagShapes.spacingM) {
                        ForEach(outlets) { outlet in
                            NavigationLink {
                                OutletDetailView(outletId: outlet.id)
                            } label: {
                                OutletCard(outlet: outlet)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, GagShapes.spacingL)
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: GagShapes.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GagColors.brandOrange)
            Text(title)
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.onSurface)
        }
    }
}

struct CategoryChip: View {
    let category: FoodCategory
    
    var body: some View {
        VStack(spacing: GagShapes.spacingXS) {
            Text(category.emoji)
                .font(.system(size: 28))
            Text(category.name)
                .font(GagTypography.labelMedium)
                .foregroundStyle(GagColors.onSurface)
                .lineLimit(1)
        }
        .frame(width: 80)
        .padding(.vertical, GagShapes.spacingM)
        .background(GagColors.surfaceVariant)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }
}

struct OutletCard: View {
    let outlet: Outlet
    
    var body: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let urlString = outlet.imageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                placeholder
                            }
                        }
                    } else {
                        placeholder
                    }
                }
                .frame(width: 160, height: 120)
                .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                
                if outlet.isOpen {
                    Circle()
                        .fill(GagColors.success)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .padding(8)
                }
            }
            
            Text(outlet.name)
                .font(GagTypography.titleSmall)
                .foregroundStyle(GagColors.onSurface)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
            
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                Text(outlet.location.building)
                    .font(GagTypography.labelSmall)
            }
            .foregroundStyle(GagColors.onSurfaceVariant)
            .frame(width: 160, alignment: .leading)
            
            if outlet.rating > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(GagColors.amber)
                    Text(String(format: "%.1f", outlet.rating))
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurface)
                }
            }
        }
    }
    
    private var placeholder: some View {
        ZStack {
            GagColors.surfaceVariant
            Image(systemName: "storefront")
                .font(.system(size: 32))
                .foregroundStyle(GagColors.onSurfaceDim)
        }
    }
}
