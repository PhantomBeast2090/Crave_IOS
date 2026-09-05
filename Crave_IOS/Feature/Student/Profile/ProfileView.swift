import SwiftUI

/// Student profile — user card, quick links, sign out.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            Section {
                userHeader
            }
            .listRowBackground(Color.clear)

            Section("Your activity") {
                NavigationLink { OrderHistoryView() } label: { menuRow("list.bullet.rectangle", "My Orders") }
                NavigationLink { FavoritesView() } label: { menuRow("heart", "Favourites") }
            }

            Section("App") {
                NavigationLink { SettingsView() } label: { menuRow("gearshape", "Settings") }
                NavigationLink { HelpView() } label: { menuRow("questionmark.circle", "Help & Support") }
            }

            Section {
                Button {
                    showSignOutConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.error)
                        Spacer()
                    }
                }
            }
        }
        .background(GagColors.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Profile")
        .confirmationDialog("Sign out of Crave?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var userHeader: some View {
        HStack(spacing: GagShapes.spacingL) {
            ZStack {
                Circle()
                    .fill(GagColors.brandOrange.opacity(0.15))
                    .frame(width: 64, height: 64)
                Text(initials)
                    .font(GagTypography.titleLarge)
                    .foregroundStyle(GagColors.brandOrange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(GagTypography.titleMedium)
                    .foregroundStyle(GagColors.onSurface)
                Text(roleLabel)
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                if let email = appState.currentUser?.email {
                    Text(email)
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurfaceDim)
                }
            }
            Spacer()
        }
        .padding(.vertical, GagShapes.spacingS)
    }

    private var displayName: String {
        appState.currentUser?.email
            .split(separator: "@").first.map(String.init) ?? "Student"
    }

    private var initials: String {
        let name = displayName
        return String(name.prefix(1)).uppercased()
    }

    private var roleLabel: String {
        guard let role = appState.currentUser?.role else { return "Signed in" }
        return role.rawValue.capitalized
    }

    private func menuRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: GagShapes.spacingM) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(GagColors.brandOrange)
            Text(title)
                .foregroundStyle(GagColors.onSurface)
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState())
}
