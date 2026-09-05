import Foundation
import Supabase

/// Supabase-backed implementation of ``AuthService``.
///
/// Mirrors the Android `SupabaseAuthRepository` behaviour:
/// - `signIn` authenticates via email/password, restores session tokens,
///   queries/creates the `profiles` row on first verified login, validates
///   `is_active`, and returns an `AuthUser`.
/// - `signUp` registers with email/password + metadata (name, phone,
///   registration_number); with email confirmation enabled the backend
///   returns no session — profile creation is deferred to the first
///   verified `signIn`.
/// - `restoreSession` uses stored access/refresh tokens via
///   `AuthClient.setSession` (equivalent to Android's `importAuthToken`).
/// - `signOut` clears the Supabase session and any local token cache.
nonisolated struct SupabaseAuthService: AuthService {
    private let client: SupabaseClient
    private let auth: AuthClient

    init() {
        self.client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
        self.auth = client.auth
    }

    // MARK: - Profile DTOs (mirror Android ProfileDto / NewProfileDto)

    private struct ProfileDto: Decodable, Sendable {
        let id: String
        let name: String
        let email: String
        let phone: String?
        let role: String
        let profile_image_url: String?
        let registration_number: String?
        let is_active: Bool
        let created_at: String
    }

    private struct NewProfileDto: Encodable, Sendable {
        let id: String
        let name: String
        let email: String
        let phone: String?
        let role: String
        let registration_number: String?
        let is_active: Bool

        init(
            id: String,
            name: String,
            email: String,
            phone: String?,
            role: String = "STUDENT",
            registration_number: String?,
            is_active: Bool = true
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.phone = phone
            self.role = role
            self.registration_number = registration_number
            self.is_active = is_active
        }
    }

    // MARK: - AuthService

    func restoreSession() async throws -> AuthUser? {
        // In the Swift SDK, the session is persisted automatically by
        // `AuthClient` (via `SessionStorage`).  On launch the stored
        // session is already loaded into `auth.currentSession`.  If the
        // access token is expired we try to refresh via the refresh token.
        guard let session = auth.currentSession else {
            return nil // Fresh install — no persisted session; valid "nil".
        }

        do {
            // `session` property auto-refreshes if expired; accessing it
            // ensures we have a valid session or throws.
            _ = try await auth.session
            return mapSessionToAuthUser(session)
        } catch {
            // Refresh failed (e.g., revoked refresh token) — treat as signed out.
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        // 1️⃣ Authenticate via email + password
        let session: Session
        do {
            session = try await auth.signIn(email: email, password: password)
        } catch let authError as AuthError {
            throw mapAuthError(authError, context: "signIn")
        } catch {
            throw AppError.network(message: error.localizedDescription)
        }

        // 2️⃣ Ensure we have a user id
        guard let userId = session.user.id.uuidString.nilIfEmpty else {
            throw AppError.unknown(message: "Session is missing user ID.")
        }

        // 3️⃣ Query profiles table for this user
        let profile: ProfileDto?
        do {
            profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            profile = nil
        }

        // 4️⃣ If profile missing → create it from user metadata (first verified login)
        let finalProfile: ProfileDto
        if let existing = profile {
            finalProfile = existing
        } else {
            let meta = session.user.userMetadata
            let nameFromMeta = (meta["name"]?.stringValue).nilIfEmpty ?? email.prefix(while: { $0 != "@" }).description
            let phoneFromMeta = (meta["phone"]?.stringValue).nilIfEmpty
            let regNoFromMeta = (meta["registration_number"]?.stringValue).nilIfEmpty

            let newProfile = NewProfileDto(
                id: userId,
                name: nameFromMeta,
                email: email,
                phone: phoneFromMeta,
                role: "STUDENT",
                registration_number: regNoFromMeta
            )

            do {
                _ = try await client
                    .from("profiles")
                    .insert(newProfile)
                    .execute()
            } catch {
                throw AppError.unknown(message: "Could not create your profile. Ensure the INSERT RLS policy is applied.")
            }

            // Re-fetch the freshly inserted profile
            do {
                finalProfile = try await client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
            } catch {
                throw AppError.unknown(message: "Profile was inserted but could not be retrieved. Please try logging in again.")
            }
        }

        // 5️⃣ Enforce `is_active`
        guard finalProfile.is_active else {
            try await auth.signOut()
            throw AppError.unknown(message: "Your account has been disabled. Please contact support.")
        }

        return AuthUser(
            id: finalProfile.id,
            email: finalProfile.email,
            role: UserRole(fromString: finalProfile.role)
        )
    }

    func signUp(
        name: String,
        email: String,
        password: String,
        phone: String?,
        registrationNumber: String?
    ) async throws -> AuthUser {
        // Build metadata exactly like Android: name, phone, registration_number
        var metadata: [String: AnyJSON] = ["name": AnyJSON.string(name)]
        if let phone, !phone.isEmpty { metadata["phone"] = AnyJSON.string(phone) }
        if let reg, !reg.isEmpty { metadata["registration_number"] = AnyJSON.string(reg) }

        do {
            let response = try await auth.signUp(
                email: email,
                password: password,
                data: metadata
            )

            // With email confirmation enabled, Supabase returns no session here.
            // Profile creation is deferred to the first verified `signIn`.
            // We return a lightweight AuthUser so the UI can proceed to the
            // "check your email" screen.
            if let user = response.user {
                return AuthUser(
                    id: user.id.uuidString,
                    email: email,
                    role: .student
                )
            } else {
                // No user in response (email confirmation required) — still return
                // a placeholder so callers can show the confirmation UI.
                return AuthUser(
                    id: "",
                    email: email,
                    role: .student
                )
            }
        } catch let authError as AuthError {
            throw mapAuthError(authError, context: "signUp")
        } catch {
            throw AppError.network(message: error.localizedDescription)
        }
    }

    func signOut() async throws {
        try await auth.signOut()
    }

    // MARK: - Helpers

    private func mapSessionToAuthUser(_ session: Session) -> AuthUser {
        AuthUser(
            id: session.user.id.uuidString,
            email: session.user.email ?? "",
            role: UserRole(fromString: (session.user.userMetadata["role"]?.stringValue) ?? "STUDENT")
        )
    }

    private func mapAuthError(_ error: AuthError, context: String) -> AppError {
        let message: String
        switch error {
        case .api(_, let code, _, _):
            switch code {
            case .invalidCredentials:
                message = "Invalid email or password."
            case .emailNotConfirmed:
                message = "Please verify your email before logging in. Check your inbox."
            case .overRequestRateLimit, .overEmailSendRateLimit:
                message = "Too many attempts. Please wait a moment and try again."
            case .userAlreadyExists, .emailExists:
                message = "An account with this email already exists."
            case .weakPassword:
                message = "Password is too weak. Please choose a stronger password."
            case .signupDisabled:
                message = "Sign-ups are currently disabled."
            case .userBanned:
                message = "This account has been banned."
            default:
                message = error.message
            }
        case .sessionMissing:
            message = "Session expired. Please log in again."
        case .weakPassword(let msg, _):
            message = msg
        case .pkceGrantCodeExchange(let msg, _, _),
             .implicitGrantRedirect(let msg):
            message = msg
        case .jwtVerificationFailed(let msg):
            message = msg
        default:
            message = error.message
        }
        return AppError.authentication(message: message)
    }
}

// MARK: - Small extensions

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension UUID {
    var uuidString: String { uuidString }
}