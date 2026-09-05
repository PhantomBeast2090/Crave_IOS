import Foundation

/// Core user model. Never decode this directly from wire DTOs — map through a mapper.
nonisolated struct User: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let role: UserRole
    let profileImageUrl: String?
    /// SRM student registration number.
    let registrationNumber: String?
    let isActive: Bool
    let createdAt: String
}

nonisolated enum UserRole: String, Sendable, Codable, CaseIterable {
    case student = "STUDENT"
    case vendor = "VENDOR"
    case admin = "ADMIN"

    init(fromString raw: String) {
        switch raw.uppercased() {
        case "STUDENT": self = .student
        case "VENDOR": self = .vendor
        case "ADMIN": self = .admin
        default: self = .student
        }
    }
}

/// Session-level auth state.
nonisolated enum AuthState: Sendable, Equatable {
    case unknown
    case unauthenticated
    case authenticated(user: AuthUser)
}

/// Lightweight authenticated user summary (no PII beyond role + id).
nonisolated struct AuthUser: Sendable, Equatable, Identifiable {
    let id: String
    let email: String
    let role: UserRole
}
