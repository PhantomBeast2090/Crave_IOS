import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SearchViewModel?
    @State private var query = ""
    @State private var showFilters = false
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading…")
                    .task { viewModel = SearchViewModel(repository: appState.repository) }
            }
        }
        .navigationTitle("Search")
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
                        ForEach(items) { item in
                            NavigationLink {
                                FoodDetailView(foodId: item.id, outletId: item.outletId)
                            } label: {
                                FoodItemCard(item: item)
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
