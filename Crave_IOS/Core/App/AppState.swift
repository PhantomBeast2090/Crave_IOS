import Foundation
import Observation

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
    }

    func signOut() async {
        try? await auth.signOut()
        currentUser = nil
        phase = .login(.student)
    }

    /// Jump to a specific role's main flow (used by login role hint / role switch).
    func enterMain(as role: UserRole) {
        phase = .main(role)
    }

    private static let onboardingKey = "crave.onboardingCompleted"
}
