import Foundation
import SwiftUI
import Combine

// Minimal SessionManager to resolve compile error and enable environment injection.
// A fuller implementation will be wired to Supabase after Android inspection.
@MainActor
final class SessionManager: ObservableObject {
    enum AuthState {
        case unknown
        case unauthenticated
        case authenticated(userId: String)
    }

    @Published private(set) var authState: AuthState = .unauthenticated
    @Published private(set) var role: UserRole? = nil

    init() {}

    func signIn(email: String, password: String) async throws {
        // Placeholder logic. Will be replaced by Supabase auth.
        authState = .authenticated(userId: "placeholder")
        role = .student
    }

    func signOut() async {
        authState = .unauthenticated
        role = nil
    }
}

enum UserRole: String {
    case student
    case vendor
    case admin
}
