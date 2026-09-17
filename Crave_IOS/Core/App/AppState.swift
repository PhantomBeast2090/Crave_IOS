import Foundation
import Observation
import Supabase
import SwiftData

/// Root app state: owns auth, onboarding flag, persistence, and the current
/// UI phase. It is the single composition root: the repository graph is built
/// eagerly in `init` so every capture of `repository` — early or late,
/// before or after sign-out — shares one backing store. There is no lazy
/// InMemory/SwiftData fallback and therefore no split-brain between views.
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

    /// SwiftData container owned by the composition root. CraveApp applies it
    /// via `.modelContainer(...)`; repositories share it as their cache.
    let modelContainer: ModelContainer

    /// True when the persistent store failed and the app fell back to an
    /// in-memory store: fully usable, but caches won't survive relaunch.
    private(set) var isPersistenceDegraded = false

    /// The single repository graph for the process lifetime. Sign-out purges
    /// user-scoped caches but keeps the same store (see `signOut`).
    private(set) var repository: AppRepository

    private let auth: any AuthService

    init(auth: (any AuthService)? = nil) {
        self.auth = auth ?? AuthServiceFactory.make()
        self.isBackendConfigured = AppConfig.isBackendConfigured
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        let (container, degraded) = Self.makeContainer()
        self.modelContainer = container
        self.isPersistenceDegraded = degraded
        self.repository = DefaultAppRepository.makeWithSwiftData(modelContainer: container)
    }

    /// Test seam: replace the repository graph (e.g. with fakes).
    func setRepository(_ repo: AppRepository) {
        repository = repo
    }

    private static func makeContainer() -> (ModelContainer, Bool) {
        do {
            return (try ModelContainer(
                for: CachedOutlet.self, CachedFoodItem.self, CartItemEntity.self,
                    OrderEntity.self, OrderItemEntity.self
            ), false)
        } catch {
            print("⚠️ [AppState] persistent store failed (\(error)); using in-memory fallback")
            // In-memory creation with a valid schema does not fail in
            // practice; the force-try only fires on programmer error
            // (invalid model definition), previously a fatalError on any
            // store issue including user-data corruption.
            return (try! ModelContainer(
                for: CachedOutlet.self, CachedFoodItem.self, CartItemEntity.self,
                    OrderEntity.self, OrderItemEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ), true)
        }
    }

    // MARK: - Lifecycle

    /// Called once at launch (from the splash screen). Restores session and routes.
    func launch() async {
        do {
            if let user = try await auth.restoreSession() {
                // userMetadata role is client-writable: re-validate against
                // the profiles row (server truth). Offline failure keeps the
                // restored role — fail open for launch, server still gates data.
                if let profile = try? await auth.fetchProfile(), profile.id == user.id {
                    currentUser = AuthUser(id: user.id, email: user.email, role: profile.role)
                } else {
                    currentUser = user
                }
                phase = .main(currentUser?.role ?? user.role)
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
        // Purge user-scoped local caches so the next login (possibly a
        // different user on a shared device) can't resurrect them. Local-only:
        // the backend cart/orders are untouched. The store itself is kept, so
        // the next session uses the same SwiftData backing (no downgrade).
        try? await repository.cart.clearLocal()
        await repository.orders.clearLocalCache()
        try? await auth.signOut()
        currentUser = nil
        phase = .login(.student)
    }

    /// Warm the outlet cache after onboarding-gated launch (fire-and-forget;
    /// failures only print). Called by the splash flow once auth is resolved.
    func launchWithRepository() async {
        await launch()

        guard hasCompletedOnboarding, isBackendConfigured else { return }

        // Inherits main-actor isolation; the network work inside
        // `refreshOutlets()` still runs off the main thread as long as
        // the repository implements it with async I/O.
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.repository.outlets.refreshOutlets()
            } catch {
                print("⚠️ Background outlet refresh failed: \(error)")
            }
        }
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

    // MARK: - Profile

    func fetchProfile() async throws -> User {
        try await auth.fetchProfile()
    }

    func updateProfile(name: String, phone: String?, registrationNumber: String?) async throws -> User {
        try await auth.updateProfile(name: name, phone: phone, registrationNumber: registrationNumber)
    }

    private static let onboardingKey = "crave.onboardingCompleted"
}
