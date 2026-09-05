import SwiftUI

/// Settings — appearance + notification prefs.
struct SettingsView: View {
    @AppStorage("crave.darkMode") private var darkMode = false

    var body: some View {
        List {
            Section("Appearance") {
                Toggle(isOn: $darkMode) {
                    Label("Dark Mode", systemImage: "moon")
                        .foregroundStyle(GagColors.onSurface)
                }
                .tint(GagColors.brandOrange)
            }

            Section("Notifications") {
                Toggle("Order Updates", isOn: .constant(true))
                    .tint(GagColors.brandOrange)
                Toggle("Promotions", isOn: .constant(false))
                    .tint(GagColors.brandOrange)
            }
        }
        .background(GagColors.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(darkMode ? .dark : nil)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
