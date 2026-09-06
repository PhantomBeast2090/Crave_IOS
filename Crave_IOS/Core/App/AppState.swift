import Foundation
import Observation
import Supabase

/// Root app state: owns auth, onboarding flag, and the current UI phase.
/// Mirrors the Android SplashViewModel start-destination logic.
@MainActor
@Observable
final class AppState {
    /// Top-level navigation phase.
    enum Phase: Equatable {
        case splash
        case onboarding
        case login(UserRole)
        case main(UserRole)
    }

    private(set) var phase: Phase = .splash

    /// The signed-in user (set on restore/sign-in/sign-up).
    private(set) var currentUser: AuthUser?

    /// True once the user has completed onboarding (persisted locally).
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    /// True when the backend isn't wired up yet — drives the "not configured" notice.
    let isBackendConfigured: Bool

    /// Backing storage for repository injection. This is resolved by `AppState+Repository.swift`.
    @ObservationIgnored var repositoryStorage: AppRepository?

    private let auth: any AuthService

    init(auth: (any AuthService)? = nil) {
        self.auth = auth ?? AuthServiceFactory.make()
        self.isBackendConfigured = AppConfig.isBackendConfigured
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    // MARK: - Lifecycle

    /// Called once at launch (from the splash screen). Restores session and routes.
    func launch() async {
        do {
            if let user = try await auth.restoreSession() {
                currentUser = user
                phase = .main(user.role)
            } else {
                phase = hasCompletedOnboarding ? .login(.student) : .onboarding
            }
        } catch {
            phase = hasCompletedOnboarding ? .login(.student) : .onboarding
        }
    }

    // MARK: - Auth actions

    func completeOnboarding() {
        hasCompletedOnboarding = true
        phase = .login(.student)
    }

    func signIn(email: String, password: String) async throws {
        let user = try await auth.signIn(email: email, password: password)
        currentUser = user
        phase = .main(user.role)
        await postAuthSync()
    }

    func signUp(name: String, email: String, password: String, phone: String?, registrationNumber: String?) async throws {
        let user = try await auth.signUp(
            name: name,
            email: email,
            password: password,
            phone: phone,
            registrationNumber: registrationNumber
        )
        currentUser = user
        phase = .main(user.role)
        await postAuthSync()
    }

    func signOut() async {
        // Drop realtime subscriptions first so no callbacks fire mid-signout.
        await SupabaseClientProvider.shared.realtimeV2.removeAllChannels()
        try? await auth.signOut()
        currentUser = nil
        phase = .login(.student)
    }

    /// Pull server state after auth: backend cart into the local store.
    /// Failures are non-fatal (offline login still works with local data).
    private func postAuthSync() async {
        do {
            try await repository.cart.syncFromBackend()
        } catch is CancellationError {
        } catch {
            print("⚠️ [AppState] post-auth cart sync failed: \(error)")
        }
    }

    /// Jump to a specific role's main flow (used by login role hint / role switch).
    func enterMain(as role: UserRole) {
        phase = .main(role)
    }

    // MARK: - Profile

    func fetchProfile() async throws -> User {
        try await auth.fetchProfile()
    }

    func updateProfile(name: String, phone: String?, registrationNumber: String?) async throws -> User {
        try await auth.updateProfile(name: name, phone: phone, registrationNumber: registrationNumber)
    }

    private static let onboardingKey = "crave.onboardingCompleted"
}
