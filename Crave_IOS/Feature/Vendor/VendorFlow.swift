import SwiftUI

/// Vendor main flow — TabView root for vendor role.
struct VendorFlow: View {
    @Environment(AppState.self) private var appState
    @State private var selection = 0

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

            NavigationStack {
                Button("Sign Out") {
                    Task { await appState.signOut() }
                }
                .navigationTitle("Profile")
            }
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(3)
        }
        .tint(GagColors.brandOrange)
    }
}

#Preview {
    VendorFlow()
        .environment(AppState())
}
