import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Credentials") {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await signIn() }
                } label: {
                    if isSigningIn { ProgressView() } else { Text("Sign In") }
                }
                .disabled(isSigningIn || email.isEmpty || password.isEmpty)
            }
            .navigationTitle("Sign In")
        }
    }

    @MainActor
    private func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            try await session.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
