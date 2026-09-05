import Foundation

/// Centralised app configuration. Secrets are sourced from `Secrets.swift`
/// (gitignored); everything else lives here.
nonisolated enum AppConfig {
    /// Supabase project URL.
    static var supabaseURL: URL {
        URL(string: Secrets.supabaseURL) ?? URL(string: "https://placeholder.supabase.co")!
    }

    /// Supabase anon (public) key — client-safe, but kept out of git.
    static var supabaseAnonKey: String {
        Secrets.supabaseAnonKey
    }

    /// True once the anon key has been pasted into `Secrets.swift`.
    static var isBackendConfigured: Bool {
        !Secrets.supabaseAnonKey.isEmpty && !Secrets.supabaseURL.contains("your-project")
    }

    static let appDisplayName = "Crave"
    static let appTagline = "Order & skip the queue"

    /// GST applied by `place_order` on the backend (server is authoritative).
    static let taxRate = 0.05

    /// Currency used throughout (INR).
    static let currencyCode = "INR"
}
