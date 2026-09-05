import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some View {
        List {
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $darkModeEnabled)
            }

            Section("Notifications") {
                Toggle("Push Notifications", isOn: $notificationsEnabled)
                Toggle("Order Updates", isOn: .constant(true))
                Toggle("Promotions", isOn: .constant(false))
            }

            Section("Account") {
                NavigationLink { EditProfileView() } label: {
                    Label("Edit Profile", systemImage: "person.circle")
                }
                NavigationLink { PaymentMethodsView() } label: {
                    Label("Payment Methods", systemImage: "creditcard")
                }
                NavigationLink { AddressesView() } label: {
                    Label("Saved Addresses", systemImage: "location")
                }
            }

            Section("Support") {
                NavigationLink { HelpView() } label: {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
                NavigationLink { AboutView() } label: {
                    Label("About", systemImage: "info.circle")
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
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone)
            }
        }
        .navigationTitle("Edit Profile")
    }
}

struct PaymentMethodsView: View {
    var body: some View {
        List {
            Section("Saved Cards") {
                Text("No saved cards")
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            Section {
                Button("Add Card") { }
            }
        }
        .navigationTitle("Payment Methods")
    }
}

struct AddressesView: View {
    var body: some View {
        List {
            Section("Saved Addresses") {
                Text("No saved addresses")
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            Section {
                Button("Add Address") { }
            }
        }
        .navigationTitle("Addresses")
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
