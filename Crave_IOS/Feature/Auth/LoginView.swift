import SwiftUI

/// Login screen. `roleHint` mirrors Android's `login?role=` argument.
struct LoginView: View {
    @Environment(AppState.self) private var appState
    let roleHint: UserRole

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showRegister = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GagShapes.spacingXL) {
                // Brand header
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppConfig.appDisplayName)
                        .font(GagTypography.displayMedium)
                        .foregroundStyle(GagColors.onBackground)
                    Text("Welcome back. Order ahead and skip the queue.")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                .padding(.top, GagShapes.spacingXXL)

                if !appState.isBackendConfigured {
                    GagNotConfiguredBanner()
                }

                VStack(spacing: GagShapes.spacingL) {
                    GagTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "you@srmist.edu.in",
                        textContentType: .emailAddress,
                        keyboardType: .emailAddress,
                        accessibilityIdentifier: "loginEmail"
                    )
                    GagTextField(
                        title: "Password",
                        text: $password,
                        kind: .secure,
                        textContentType: .password,
                        accessibilityIdentifier: "loginPassword"
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(GagTypography.labelMedium)
                        .foregroundStyle(GagColors.error)
                }

                GagButton(
                    title: "Sign In",
                    isLoading: isSigningIn,
                    isEnabled: !email.isEmpty && !password.isEmpty,
                    accessibilityIdentifier: "signInButton",
                    action: { Task { await signIn() } }
                )

                HStack(spacing: GagShapes.spacingXS) {
                    Text("New here?")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                    Button("Create an account") {
                        showRegister = true
                    }
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.brandOrange)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, GagShapes.spacingXL)
        }
        .background(GagColors.background)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }

    @MainActor
    private func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            try await appState.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView(roleHint: .student)
        .environment(AppState())
}
