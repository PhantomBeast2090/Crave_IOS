import Foundation
import Supabase

/// Single shared Supabase client for the whole app.
///
/// All repositories and services MUST use this instead of constructing their
/// own `SupabaseClient`. Separate instances keep separate auth sessions, so a
/// second client would silently lose the signed-in session (RLS failures) and
/// open duplicate Realtime connections.
enum SupabaseClientProvider {
    /// Nonisolated: `SupabaseClient` is a `Sendable` final class, so sharing
    /// it needs no actor. (The file default is `@MainActor`; without this,
    /// every `= SupabaseClientProvider.shared` default argument warns.)
    nonisolated static let shared: SupabaseClient = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
