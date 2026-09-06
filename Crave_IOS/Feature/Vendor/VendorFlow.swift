import SwiftUI

/// Vendor main flow — TabView root for vendor role.
struct VendorFlow: View {
    @Environment(AppState.self) private var appState
    @State private var selection = 0
    @State private var showSignOutConfirmation = false

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { VendorDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(0)

            NavigationStack { VendorOrdersView() }
                .tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }
                .tag(1)

            NavigationStack { VendorMenuView() }
                .tabItem { Label("Menu", systemImage: "menucard") }
                .tag(2)

            NavigationStack { VendorScannerView() }
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
                .tag(3)

            NavigationStack { VendorAnalyticsView() }
                .tabItem { Label("Analytics", systemImage: "chart.bar") }
                .tag(4)

            NavigationStack {
                List {
                    Section {
                        HStack {
                            Spacer()
                            Button("Sign Out", role: .destructive) {
                                showSignOutConfirmation = true
                            }
                            Spacer()
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(GagColors.background)
                .navigationTitle("Profile")
                .confirmationDialog("Sign out of Crave?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                    Button("Sign Out", role: .destructive) {
                        Task { await appState.signOut() }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(5)
        }
        .tint(GagColors.brandOrange)
    }
}

#Preview {
    VendorFlow()
        .environment(AppState())
}
