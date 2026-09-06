import SwiftUI

/// Settings (mirrors Android SettingsScreen): push-notification preference,
/// System/Light/Dark theme, help, about, sign out. Every row is functional —
/// no placeholder screens.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var themeManager = ThemeManager.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showThemePicker = false

    var body: some View {
        List {
            Section("Preferences") {
                HStack(spacing: GagShapes.spacingM) {
                    Image(systemName: "bell")
                        .frame(width: 22)
                        .foregroundStyle(GagColors.brandOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Push Notifications")
                            .foregroundStyle(GagColors.onSurface)
                        Text("Receive updates about your orders")
                            .font(GagTypography.bodySmall)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                }

                Button {
                    showThemePicker = true
                } label: {
                    HStack(spacing: GagShapes.spacingM) {
                        Image(systemName: "circle.lefthalf.filled")
                            .frame(width: 22)
                            .foregroundStyle(GagColors.brandOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Theme")
                                .foregroundStyle(GagColors.onSurface)
                            Text(themeManager.mode.displayName)
                                .font(GagTypography.bodySmall)
                                .foregroundStyle(GagColors.onSurfaceVariant)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GagColors.onSurfaceDim)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Support") {
                NavigationLink { HelpView() } label: {
                    Label("Help & Support", systemImage: "questionmark.circle")
                        .foregroundStyle(GagColors.onSurface)
                }
                NavigationLink { AboutView() } label: {
                    Label("About", systemImage: "info.circle")
                        .foregroundStyle(GagColors.onSurface)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await appState.signOut() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                            .foregroundStyle(GagColors.error)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .background(AppTheme.screenBackground)
        .scrollContentBackground(.hidden)
        .confirmationDialog("Select Theme", isPresented: $showThemePicker, titleVisibility: .visible) {
            ForEach(AppThemeMode.allCases, id: \.self) { mode in
                Button(mode.displayName) {
                    themeManager.mode = mode
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(GagColors.brandOrange)
                        Text(AppConfig.appDisplayName)
                            .font(GagTypography.titleLarge)
                        Text("Version 1.0.0")
                            .font(GagTypography.bodySmall)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                    Spacer()
                }
            }

            Section("Legal") {
                Label("Terms of Service", systemImage: "doc.text")
                Label("Privacy Policy", systemImage: "hand.raised")
            }
        }
        .navigationTitle("About")
    }
}
