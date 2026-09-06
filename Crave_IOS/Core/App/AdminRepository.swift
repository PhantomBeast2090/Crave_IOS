import Foundation

// MARK: - Admin Repository Protocol (mirrors Android AdminRepository)

protocol AdminRepository: Sendable {
    /// `get_admin_stats()` — reads `profiles`, fully server-side.
    func getSystemStats() async throws -> SystemStats

    /// `admin_toggle_outlet_status`.
    func toggleOutletStatus(outletId: String, isOpen: Bool) async throws
}
