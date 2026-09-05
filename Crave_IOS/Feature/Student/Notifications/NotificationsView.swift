import SwiftUI

/// In-app notifications — fed by the `notifications` table + Realtime.
struct NotificationsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GagEmptyView(
                    icon: "bell",
                    title: "No notifications",
                    message: "Order updates will appear here in real time."
                )
                .padding(.top, 120)
            }
        }
        .background(GagColors.background)
        .navigationTitle("Notifications")
    }
}

#Preview {
    NavigationStack { NotificationsView() }
}
