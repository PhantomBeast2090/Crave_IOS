import Foundation
import Supabase

/// Admin backend. `get_admin_stats()` reads `profiles` (migration 009), so
/// there is no `users`-table issue in this backend — stats come straight
/// from the RPC.
struct SupabaseAdminRepository: AdminRepository, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func getSystemStats() async throws -> SystemStats {
        do {
            return try await client.rpc("get_admin_stats").execute().value
        } catch {
            print("❌ [Admin] get_admin_stats failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Couldn't load admin stats.")
        }
    }

    func toggleOutletStatus(outletId: String, isOpen: Bool) async throws {
        do {
            try await client
                .rpc("admin_toggle_outlet_status",
                     params: ToggleOutletStatusParams(outletId: outletId, isOpen: isOpen))
                .execute()
        } catch {
            print("❌ [Admin] toggle outlet failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Couldn't update outlet status.")
        }
    }
}
