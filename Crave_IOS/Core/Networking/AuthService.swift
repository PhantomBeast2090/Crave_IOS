import Foundation

// =============================================================================
// Auth service abstraction.
//
// The concrete implementation talks to Supabase GoTrue (added in the
// Supabase-integration stage). Until the backend anon key is configured, the
// app uses `UnconfiguredAuthService`, which fails fast with a clear message so
// nothing pretends to work.
// =============================================================================

/// Authentication gateway used by `AppState`.
nonisolated protocol AuthService: Sendable {
    /// Restore a persisted session at launch. Returns nil when signed out.
    func restoreSession() async throws -> AuthUser?
    /// Sign in with email + password. First verified sign-in creates a profile.
    func signIn(email: String, password: String) async throws -> AuthUser
    /// Register a new student account.
    func signUp(
        name: String,
        email: String,
        password: String,
        phone: String?,
        registrationNumber: String?
    ) async throws -> AuthUser
    /// Sign out — clears session + realtime channels.
    func signOut() async throws
}

/// Used until the Supabase anon key is present in `Secrets.swift`.
nonisolated struct UnconfiguredAuthService: AuthService {
    func restoreSession() async throws -> AuthUser? {
        // Fresh install — no persisted session; that's a valid "nil", not an error.
        nil
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        throw AppError.notConfigured
    }

    func signUp(name: String, email: String, password: String, phone: String?, registrationNumber: String?) async throws -> AuthUser {
        throw AppError.notConfigured
    }

    func signOut() async throws {}
}

/// Factory — swaps in the real Supabase-backed service once configured.
nonisolated enum AuthServiceFactory {
    static func make() -> any AuthService {
        guard AppConfig.isBackendConfigured else { return UnconfiguredAuthService() }
        return SupabaseAuthService()
    }
}
