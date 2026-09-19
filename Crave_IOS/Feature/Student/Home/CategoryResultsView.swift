import SwiftUI

/// Dedicated food-type discovery for one category: outlets serving it +
/// their matching dishes. Distinct from Search (see SearchView).
struct CategoryResultsView: View {
    let category: FoodCategory
    @Environment(AppState.self) private var appState
    @State private var viewModel: CategoryResultsViewModel?
    @State private var quickAdd: QuickAddHelper?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading \(category.name)…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await setup() }
        .refreshable { await viewModel?.refresh() }
        .alert("Different Outlet", isPresented: conflictBinding) {
            Button("Clear & Add", role: .destructive) {
                quickAdd?.confirmConflictAdd()
            }
            Button("Keep Cart", role: .cancel) {
                quickAdd?.dismissConflict()
            }
        } message: {
            Text("Your cart contains items from a different outlet. Clear cart and add from this outlet?")
        }
        .navigationDestination(item: detailBinding) { item in
            FoodDetailView(foodId: item.id, outletId: item.outletId)
        }
        .overlay(alignment: .bottom) {
            if let message = quickAdd?.toastMessage {
                GagToast(message: message)
                    .padding(.bottom, 90)
            }
        }
    }

    private func setup() async {
        if quickAdd == nil {
            quickAdd = QuickAddHelper(repository: appState.repository.cart)
        }
        if viewModel == nil {
            let vm = CategoryResultsViewModel(category: category, repository: appState.repository)
            viewModel = vm
            await vm.load()
        }
    }

    private var detailBinding: Binding<FoodItem?> {
        Binding(
            get: { quickAdd?.detailItem },
            set: { quickAdd?.detailItem = $0 }
        )
    }

    private var conflictBinding: Binding<Bool> {
        Binding(
            get: { quickAdd?.conflictItem != nil },
            set: { if !$0 { quickAdd?.dismissConflict() } }
        )
    }

    @ViewBuilder
    private func content(viewModel: CategoryResultsViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Finding \(category.name) around campus…")
        case .empty:
            GagEmptyView(
                icon: "fork.knife",
                title: "No \(category.name) right now",
                message: "No outlet is serving this at the moment. Check back later."
            )
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded:
            resultsList(viewModel: viewModel)
        }
    }

    private func resultsList(viewModel: CategoryResultsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                Text("Find it around campus")
                    .font(GagTypography.titleSmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .padding(.horizontal, GagShapes.spacingL)

                Text("\(viewModel.dishCount) dishes across \(viewModel.visibleSections.count) outlets")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .padding(.horizontal, GagShapes.spacingL)

                filterRow(viewModel: viewModel)

                ForEach(viewModel.visibleSections) { section in
                    outletSection(section)
                }
            }
            .padding(.vertical, GagShapes.spacingM)
        }
    }

    private func filterRow(viewModel: CategoryResultsViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GagShapes.spacingS) {
                ForEach(CategoryResultsViewModel.DietFilter.allCases) { option in
                    Button {
                        viewModel.dietFilter = option
                    } label: {
                        Text(option.rawValue)
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(viewModel.dietFilter == option ? .white : GagColors.onSurface)
                            .padding(.horizontal, GagShapes.spacingM)
                            .padding(.vertical, GagShapes.spacingS)
                            .background(
                                viewModel.dietFilter == option
                                    ? GagColors.brandOrange
                                    : GagColors.surfaceVariant
                            )
                            .clipShape(GagShapes.cornerRadius(GagShapes.radiusPill))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    viewModel.under100Only.toggle()
                } label: {
                    Text("Under ₹100")
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(viewModel.under100Only ? .white : GagColors.onSurface)
                        .padding(.horizontal, GagShapes.spacingM)
                        .padding(.vertical, GagShapes.spacingS)
                        .background(
                            viewModel.under100Only
                                ? GagColors.brandOrange
                                : GagColors.surfaceVariant
                        )
                        .clipShape(GagShapes.cornerRadius(GagShapes.radiusPill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, GagShapes.spacingL)
        }
    }

    private func outletSection(_ section: CategoryOutlet) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
            NavigationLink {
                OutletDetailView(outletId: section.outletId)
            } label: {
                HStack {
                    Text(section.outletName)
                        .font(GagTypography.titleSmall)
                        .foregroundStyle(GagColors.onSurface)
                    Spacer()
                    Text("\(section.dishes.count) options" + (section.dishes.count == 1 ? "" : "s"))
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                    if let from = section.fromPrice {
                        Text("from \(Formatters.price(from))")
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.brandOrange)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GagColors.onSurfaceDim)
                }
                .padding(.horizontal, GagShapes.spacingL)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("categoryOutletRow")

            ForEach(section.dishes) { dish in
                NavigationLink {
                    FoodDetailView(foodId: dish.id, outletId: dish.outletId)
                } label: {
                    FoodItemCard(item: dish, onAddToCart: { quickAdd?.quickAdd(dish) })
                        .padding(.horizontal, GagShapes.spacingL)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, GagShapes.spacingS)
    }
}
