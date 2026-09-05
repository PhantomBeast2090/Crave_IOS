import SwiftUI

/// Bottom navigation item.
nonisolated struct BottomNavItem: Hashable, Sendable {
    let title: String
    let icon: String
    let tag: Int
}

/// Material-style bottom navigation bar (Android GagBottomNav parity).
struct GagBottomNav: View {
    let items: [BottomNavItem]
    @Binding var selection: Int

    var body: some View {
        HStack {
            ForEach(items, id: \.tag) { item in
                let isSelected = selection == item.tag
                Button {
                    withAnimation(.spring(duration: 0.25)) { selection = item.tag }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        Text(item.title)
                            .font(isSelected ? GagTypography.labelSmall : GagTypography.labelSmall)
                    }
                    .foregroundStyle(isSelected ? GagColors.brandOrange : GagColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(GagColors.bottomNavBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GagColors.bottomNavBorder)
                .frame(height: 1)
        }
    }
}

#Preview {
    @Previewable @State var selection = 0
    GagBottomNav(
        items: [
            BottomNavItem(title: "Home", icon: "house", tag: 0),
            BottomNavItem(title: "Search", icon: "magnifyingglass", tag: 1),
            BottomNavItem(title: "Orders", icon: "list.bullet.rectangle", tag: 2),
            BottomNavItem(title: "Profile", icon: "person", tag: 3),
        ],
        selection: $selection
    )
}
