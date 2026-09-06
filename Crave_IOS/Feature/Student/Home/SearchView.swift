import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SearchViewModel?
    @State private var quickAdd: QuickAddHelper?
    @State private var query = ""
    @State private var showFilters = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading…")
            }
        }
        // `.task` on the outer Group so branch swaps can't cancel setup.
        .task {
            if viewModel == nil {
                viewModel = SearchViewModel(repository: appState.repository)
            }
            if quickAdd == nil {
                quickAdd = QuickAddHelper(repository: appState.repository.cart)
            }
        }
        .navigationTitle("Search")
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $query, prompt: "Search food, outlets...")
        .onChange(of: query) { _, newValue in
            viewModel?.updateQuery(newValue)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(GagColors.brandOrange)
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            SearchFiltersView(filter: Binding(
                get: { viewModel?.filter ?? FoodSearchFilter() },
                set: { viewModel?.updateFilter($0) }
            ))
        }
        .navigationDestination(item: detailBinding) { item in
            FoodDetailView(foodId: item.id, outletId: item.outletId)
        }
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
        .overlay(alignment: .bottom) {
            if let message = quickAdd?.toastMessage {
                GagToast(message: message)
                    .padding(.bottom, 90)
            }
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
    private func content(viewModel: SearchViewModel) -> some View {
        switch viewModel.state {
        case .idle:
            GagEmptyView(
                icon: "magnifyingglass",
                title: "Search for food",
                message: "Type to search across all outlets"
            )
            
        case .loading:
            GagLoadingView(message: "Searching…")
            
        case .results(let items):
            if items.isEmpty {
                GagEmptyView(
                    icon: "magnifyingglass",
                    title: "No results",
                    message: "Try a different search term"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: GagShapes.spacingM) {
                        if let addError = quickAdd?.errorMessage {
                            Text(addError)
                                .font(GagTypography.labelMedium)
                                .foregroundStyle(GagColors.error)
                        }
                        ForEach(items) { item in
                            NavigationLink {
                                FoodDetailView(foodId: item.id, outletId: item.outletId)
                            } label: {
                                FoodItemCard(item: item, onAddToCart: { quickAdd?.quickAdd(item) })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(GagShapes.spacingL)
                }
            }
            
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.performSearch() }
            }
        }
    }
}

struct SearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: FoodSearchFilter
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dietary") {
                    Picker("Vegetarian", selection: Binding(
                        get: { filter.isVeg },
                        set: { filter.isVeg = $0 }
                    )) {
                        Text("All").tag(nil as Bool?)
                        Text("Vegetarian only").tag(true)
                        Text("Non-veg only").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Price") {
                    HStack {
                        Text("Max price")
                        Spacer()
                        TextField("₹", value: Binding(
                            get: { filter.maxPrice },
                            set: { filter.maxPrice = $0 }
                        ), format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
                
                Section("Availability") {
                    Toggle("Available only", isOn: Binding(
                        get: { filter.availableOnly },
                        set: { filter.availableOnly = $0 }
                    ))
                }
                
                Section("Sort") {
                    Picker("Sort by", selection: Binding(
                        get: { filter.sortBy },
                        set: { filter.sortBy = $0 }
                    )) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }
                
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        filter = FoodSearchFilter()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
