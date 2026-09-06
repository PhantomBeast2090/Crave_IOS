import SwiftUI

/// Student registration. Backend only allows STUDENT profile self-insert (RLS).
struct RegisterView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var registrationNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var showVerifyEmail = false

    private var isValid: Bool {
        !name.isEmpty
            && email.contains("@")
            && password.count >= 8
            && password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create your account")
                            .font(GagTypography.titleLarge)
                            .foregroundStyle(GagColors.onBackground)
                        Text("Sign up as a student to start ordering.")
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                    .padding(.top, GagShapes.spacingXL)

                    VStack(spacing: GagShapes.spacingL) {
                        GagTextField(title: "Full Name", text: $name, placeholder: "Jane Doe", autocapitalization: .words, accessibilityIdentifier: "registerName")
                        GagTextField(
                            title: "Email",
                            text: $email,
                            placeholder: "you@srmist.edu.in",
                            textContentType: .emailAddress,
                            keyboardType: .emailAddress,
                            accessibilityIdentifier: "registerEmail"
                        )
                        GagTextField(
                            title: "Phone (optional)",
                            text: $phone,
                            placeholder: "+91",
                            textContentType: .telephoneNumber,
                            keyboardType: .phonePad,
                            accessibilityIdentifier: "registerPhone"
                        )
                        GagTextField(
                            title: "Registration Number",
                            text: $registrationNumber,
                            placeholder: "RA2411003010001",
                            autocapitalization: .characters,
                            accessibilityIdentifier: "registerRegNo"
                        )
                        GagTextField(title: "Password", text: $password, kind: .secure, textContentType: .newPassword, accessibilityIdentifier: "registerPassword")
                        GagTextField(title: "Confirm Password", text: $confirmPassword, kind: .secure, textContentType: .newPassword, accessibilityIdentifier: "registerConfirm")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.error)
                    }

                    GagButton(
                        title: "Create Account",
                        isLoading: isRegistering,
                        isEnabled: isValid,
                        accessibilityIdentifier: "createAccountButton",
                        action: { Task { await register() } }
                    )
                }
                .padding(.horizontal, GagShapes.spacingXL)
            }
            .background(GagColors.background)
            .scrollDismissesKeyboard(.interactively)
            .alert("Verify Your Email", isPresented: $showVerifyEmail) {
                Button("Go to Login") { dismiss() }
            } message: {
                Text("We've sent a confirmation link to your email address. Please verify your email before logging in.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(GagColors.onSurface)
                    }
                }
            }
        }
    }

    @MainActor
    private func register() async {
        guard !isRegistering else { return }
        isRegistering = true
        errorMessage = nil
        defer { isRegistering = false }

        do {
            try await appState.signUp(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                phone: phone.isEmpty ? nil : phone,
                registrationNumber: registrationNumber.isEmpty ? nil : registrationNumber
            )
            dismiss()
        } catch let appError as AppError {
            if appError == .emailConfirmationRequired {
                showVerifyEmail = true
            } else {
                errorMessage = appError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RegisterView()
        .environment(AppState())
}
