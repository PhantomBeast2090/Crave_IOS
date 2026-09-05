import SwiftUI

struct MainTabView: View {
    let userRole: UserRole
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            NavigationStack {
                OrdersView()
            }
            .tabItem {
                Label("Orders", systemImage: "bag.fill")
            }
            .tag(2)
            
            NavigationStack {
                CartView()
            }
            .tabItem {
                Label("Cart", systemImage: "cart.fill")
            }
            .tag(3)
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(4)
        }
        .tint(GagColors.brandOrange)
        .onAppear {
            // Pre-load outlets
            if appState.hasCompletedOnboarding {
                Task { @MainActor in
                    _ = try? await appState.repository.outlets.refreshOutlets()
                }
            }
        }
    }
}
