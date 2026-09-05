import SwiftUI

/// Favourites — driven by the `favorites` table once wired.
struct FavoritesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GagEmptyView(
                    icon: "heart",
                    title: "No favourites yet",
                    message: "Tap the heart on any dish to save it here."
                )
                .padding(.top, 120)
            }
        }
        .background(GagColors.background)
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { FavoritesView() }
}
