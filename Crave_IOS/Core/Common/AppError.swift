import Foundation

/// Domain-level errors surfaced to the UI. Never contains tokens or secrets.
nonisolated enum AppError: LocalizedError, Sendable, Equatable {
    case notConfigured
    case invalidCredentials
    case network(statusCode: Int, message: String)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Backend is not configured yet. Paste the Supabase anon key into Core/Config/Secrets.swift."
        case .invalidCredentials:
            return "Invalid email or password."
        case .network(let code, let message):
            return "Network error (\(code)): \(message)"
        case .message(let m):
            return m
        }
    }
}
