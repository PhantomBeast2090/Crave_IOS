import SwiftUI

/// Student main flow — TabView root with per-tab navigation stacks.
/// Tabs mirror Android's bottom nav exactly (Home, Orders, Favorites,
/// Alerts, Profile) so iOS never overflows into a "More" tab. Search opens
/// from the Home header's search field, like Android.
struct StudentFlow: View {
    @Environment(AppState.self) private var appState
    @State private var selection = 0
    @State private var unreadCount = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            NavigationStack { OrderHistoryView() }
                .tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }
                .tag(1)

            NavigationStack { FavoritesView() }
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(2)

            NavigationStack { NotificationsView() }
                .tabItem { Label("Alerts", systemImage: "bell") }
                .badge(unreadCount)
                .tag(3)

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(4)
        }
        .tint(GagColors.brandOrange)
        .task { await refreshBadges() }
        .onChange(of: selection) { _, _ in
            Task { await refreshBadges() }
        }
    }

    private func refreshBadges() async {
        let enabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard enabled else {
            unreadCount = 0
            return
        }
        unreadCount = (try? await appState.repository.notifications.refreshNotifications())?
            .filter { !$0.isRead }.count ?? 0
    }
}

#Preview {
    StudentFlow()
        .environment(AppState())
}
