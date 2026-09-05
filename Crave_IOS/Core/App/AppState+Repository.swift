import Foundation
import Observation
import SwiftData

extension AppState {
    @MainActor
    var repository: AppRepository {
        if let existing = repositoryStorage {
            return existing
        }
        // Fallback: in-memory repository until one is injected from the environment.
        let repo = DefaultAppRepository.makeInMemory()
        repositoryStorage = repo
        return repo
    }

    @MainActor
    func setRepository(_ repo: AppRepository) {
        repositoryStorage = repo
    }

    @MainActor
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
}
