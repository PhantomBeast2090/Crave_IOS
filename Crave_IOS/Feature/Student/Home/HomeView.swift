import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel?
    @State private var cartCount = 0
    @State private var unreadCount = 0
    @State private var showSearch = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading…")
            }
        }
        // NOTE: `.task` lives on the outer Group (not the else-branch) so that
        // assigning `viewModel` — which swaps the branch — doesn't cancel the
        // in-flight load with a CancellationError.
        .task { await setupViewModel() }
        // Live badge streams: the toolbar cart/alerts badges must reflect
        // adds the moment they happen (even while a detail screen is pushed),
        // not just on first appear or pull-to-refresh.
        .task {
            for await cart in appState.repository.cart.observeCart() {
                cartCount = cart?.totalItems ?? 0
            }
        }
        .task {
            guard UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true else {
                unreadCount = 0
                return
            }
            for await items in appState.repository.notifications.observeNotifications() {
                unreadCount = items.filter { !$0.isRead }.count
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: GagShapes.spacingM) {
                    if !appState.isBackendConfigured {
                        Image(systemName: "key.slash")
                            .foregroundStyle(GagColors.amber)
                    }
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        badgeIcon("bell", count: unreadCount)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("notificationsButton")
                    NavigationLink {
                        CartView()
                    } label: {
                        badgeIcon("cart", count: cartCount)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cartButton")
                }
            }
        }
        .refreshable {
            await viewModel?.refresh()
            await refreshBadges()
        }
        .navigationDestination(isPresented: $showSearch) {
            SearchView()
        }
    }

    private func badgeIcon(_ systemName: String, count: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundStyle(GagColors.onSurface)
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(GagColors.brandOrange)
                    .clipShape(Capsule())
                    .offset(x: 10, y: -8)
            }
        }
    }

    private func refreshBadges() async {
        cartCount = await appState.repository.cart.currentCart()?.totalItems ?? 0
        let enabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard enabled else {
            unreadCount = 0
            return
        }
        unreadCount = (try? await appState.repository.notifications.refreshNotifications())?
            .filter { !$0.isRead }.count ?? 0
    }
    
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = HomeViewModel(repository: appState.repository)
        self.viewModel = vm
        await vm.load()
        await refreshBadges()
    }

    @ViewBuilder
    private func content(viewModel: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                heroHeader

                // Fake search field (Android parity) → real Search screen.
                Button {
                    showSearch = true
                } label: {
                    HStack(spacing: GagShapes.spacingM) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundStyle(GagColors.onSurfaceVariant)
                        Text("Search food, outlets…")
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.onSurfaceDim)
                        Spacer()
                    }
                    .padding(GagShapes.spacingM)
                    .background(GagColors.surface)
                    .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                    .overlay(
                        GagShapes.cornerRadius(GagShapes.radiusLarge)
                            .stroke(GagColors.outlineVariant, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("homeSearchField")
                .padding(.horizontal, GagShapes.spacingL)

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
                        NavigationLink {
                            SearchView()
                        } label: {
                            CategoryChip(category: category)
                        }
                        .buttonStyle(.plain)
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
                            .accessibilityIdentifier("outletCard")
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
