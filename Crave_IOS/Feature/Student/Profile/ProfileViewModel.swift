import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    enum State {
        case idle
        case loading
        case loaded(User)
        case error(message: String)
    }

    private(set) var state: State = .idle
    private(set) var isSaving = false
    private(set) var saveError: String?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var user: User? {
        if case .loaded(let user) = state { return user }
        return nil
    }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = .loaded(try await appState.fetchProfile())
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    func refresh() async {
        state = .idle
        await load()
    }

    func save(name: String, phone: String?, registrationNumber: String?) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            state = .loaded(try await appState.updateProfile(
                name: name,
                phone: phone?.isEmpty == true ? nil : phone,
                registrationNumber: registrationNumber?.isEmpty == true ? nil : registrationNumber
            ))
            return true
        } catch is CancellationError {
            return false
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
