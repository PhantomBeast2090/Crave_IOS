import SwiftUI

/// Student profile — user card, quick links, edit profile, sign out
/// (mirrors Android ProfileScreen).
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: ProfileViewModel?
    @State private var showSignOutConfirmation = false
    @State private var showEditProfile = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading profile…")
            }
        }
        .background(GagColors.background)
        .navigationTitle("Profile")
        .task { await setupViewModel() }
        .sheet(isPresented: $showEditProfile) {
            if let user = viewModel?.user {
                NavigationStack {
                    EditProfileSheet(user: user) { name, phone, reg in
                        await viewModel?.save(name: name, phone: phone, registrationNumber: reg) ?? false
                    }
                }
            }
        }
        .confirmationDialog("Sign out of Crave?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = ProfileViewModel(appState: appState)
        self.viewModel = vm
        await vm.load()
    }

    @ViewBuilder
    private func content(viewModel: ProfileViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            GagLoadingView(message: "Loading profile…")
        case .error(let message):
            GagErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, GagShapes.spacingL)
        case .loaded(let user):
            profileContent(user: user)
        }
    }

    private func profileContent(user: User) -> some View {
        List {
            Section {
                userHeader(user)
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
        .scrollContentBackground(.hidden)
        .refreshable { [weak viewModel] in await viewModel?.refresh() }
    }

    private func userHeader(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            HStack(spacing: GagShapes.spacingL) {
                ZStack {
                    Circle()
                        .fill(GagColors.brandOrange.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Text(initials(for: user.name))
                        .font(GagTypography.titleLarge)
                        .foregroundStyle(GagColors.brandOrange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name.isEmpty ? "Student" : user.name)
                        .font(GagTypography.titleMedium)
                        .foregroundStyle(GagColors.onSurface)
                    Text(user.role.rawValue.capitalized)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                    Text(user.email)
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurfaceDim)
                }
                Spacer()
            }

            if let phone = user.phone, !phone.isEmpty {
                Label(phone, systemImage: "phone")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
            if let reg = user.registrationNumber, !reg.isEmpty {
                Label(reg, systemImage: "badge")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }

            Button {
                showEditProfile = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.brandOrange)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, GagShapes.spacingS)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? String(parts.last?.prefix(1) ?? "") : ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "S" : result
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

/// Edit profile sheet (mirrors Android's edit dialog): name/phone/
/// registration number only — role is never editable.
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phone: String
    @State private var registrationNumber: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    let save: (String, String?, String?) async -> Bool

    init(user: User, save: @escaping (String, String?, String?) async -> Bool) {
        self._name = State(initialValue: user.name)
        self._phone = State(initialValue: user.phone ?? "")
        self._registrationNumber = State(initialValue: user.registrationNumber ?? "")
        self.save = save
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Full Name", text: $name)
                    .textContentType(.name)
                TextField("Phone Number", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Registration Number", text: $registrationNumber)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.error)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        if await save(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            phone.isEmpty ? nil : phone,
                            registrationNumber.isEmpty ? nil : registrationNumber
                        ) {
                            dismiss()
                        } else {
                            errorMessage = "Couldn't save. Please try again."
                        }
                    }
                }
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .disabled(isSaving)
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState())
}
