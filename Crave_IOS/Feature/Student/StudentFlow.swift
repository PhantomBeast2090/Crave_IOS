import SwiftUI

/// Student main flow — TabView root with per-tab navigation stacks.
struct StudentFlow: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            NavigationStack { OrderHistoryView() }
                .tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }
                .tag(2)

            NavigationStack { NotificationsView() }
                .tabItem { Label("Alerts", systemImage: "bell") }
                .tag(3)

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(4)
        }
        .tint(GagColors.brandOrange)
    }
}

#Preview {
    StudentFlow()
        .environment(AppState())
}
