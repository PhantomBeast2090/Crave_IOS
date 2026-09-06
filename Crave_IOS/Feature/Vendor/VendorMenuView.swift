import SwiftUI

/// Vendor menu management (mirrors Android VendorMenuScreen + the
/// backend-supported price update): availability switch + price editing.
struct VendorMenuView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: VendorMenuViewModel?
    @State private var editingItem: FoodItem?
    @State private var editedPrice = ""

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading menu…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Manage Menu")
        .task { await setupViewModel() }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                Form {
                    Section("Price for \(item.name)") {
                        HStack {
                            Text("₹")
                            TextField("Price", text: $editedPrice)
                                .keyboardType(.decimalPad)
                        }
                    }
                    Section {
                        Button("Save Price") {
                            Task {
                                if let price = Double(editedPrice), price > 0,
                                   await viewModel?.updatePrice(item, price: price) == true {
                                    editingItem = nil
                                }
                            }
                        }
                        .disabled((Double(editedPrice) ?? 0) <= 0)
                    }
                }
                .navigationTitle("Edit Price")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { editingItem = nil }
                    }
                }
                .onAppear {
                    editedPrice = String(format: "%.2f", item.price)
                }
            }
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = VendorMenuViewModel(repository: appState.repository.food)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: VendorMenuViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading menu…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let items):
            if items.isEmpty {
                GagEmptyView(icon: "menucard", title: "No menu items found.", message: "")
                    .padding(.top, 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: GagShapes.spacingM) {
                        if let actionError = viewModel.actionError {
                            Text(actionError)
                                .font(GagTypography.labelMedium)
                                .foregroundStyle(GagColors.error)
                        }
                        ForEach(items) { item in
                            menuRow(item, viewModel: viewModel)
                        }
                    }
                    .padding(GagShapes.spacingL)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }

    private func menuRow(_ item: FoodItem, viewModel: VendorMenuViewModel) -> some View {
        HStack(spacing: GagShapes.spacingM) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurface)
                Text("\(Formatters.price(item.price)) · \(item.category)")
                    .font(GagTypography.labelSmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                Text(item.isAvailable ? "Available" : "Out of Stock")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(item.isAvailable ? GagColors.success : GagColors.error)
            }
            Spacer()
            if viewModel.updatingItemId == item.id {
                ProgressView().tint(GagColors.brandOrange)
            } else {
                Button {
                    editingItem = item
                } label: {
                    Image(systemName: "indianrupeesign.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(GagColors.brandOrange)
                }
                .buttonStyle(.plain)
                Toggle("", isOn: Binding(
                    get: { item.isAvailable },
                    set: { _ in Task { await viewModel.toggleAvailability(item) } }
                ))
                .labelsHidden()
                .tint(GagColors.success)
            }
        }
        .padding(GagShapes.spacingM)
        .background(GagColors.surface)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }
}

#Preview {
    NavigationStack { VendorMenuView() }
        .environment(AppState())
}
