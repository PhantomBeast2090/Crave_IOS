import Foundation
import Supabase

/// Supabase-backed OutletRepository implementation.
/// Mirrors Android's SupabaseOutletRepository exactly.
final class SupabaseOutletRepository: OutletRepository, Sendable {
    private let client: SupabaseClient
    private let localCache: OutletLocalCache
    
    init(client: SupabaseClient, localCache: OutletLocalCache) {
        self.client = client
        self.localCache = localCache
    }
    
    // MARK: - OutletRepository
    
    func observeOutlets() -> AsyncStream<[Outlet]> {
        localCache.observeOutlets()
    }
    
    func refreshOutlets() async throws -> [Outlet] {
        print("🔄 [SupabaseOutletRepo] Refreshing outlets from Supabase...")
        
        let dtos: [OutletDto] = try await client
            .from("outlets")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
        
        print("✅ [SupabaseOutletRepo] Retrieved \(dtos.count) outlets")
        
        let outlets = dtos.map { $0.toDomain() }
        try await localCache.saveOutlets(outlets)
        
        return outlets
    }
    
    func getOutletById(_ outletId: String) async throws -> Outlet {
        // Check local cache first
        if let cached = await localCache.getOutletById(outletId) {
            print("💾 [SupabaseOutletRepo] Cache hit for outlet \(outletId)")
            return cached
        }
        
        print("🌐 [SupabaseOutletRepo] Fetching outlet \(outletId) from Supabase...")
        
        let dto: OutletDto = try await client
            .from("outlets")
            .select()
            .eq("id", value: outletId)
            .single()
            .execute()
            .value
        
        let outlet = dto.toDomain()
        try await localCache.saveOutlet(outlet)
        
        return outlet
    }
    
    func getNearbyOutlets(lat: Double, lng: Double) async throws -> [Outlet] {
        // Note: PostGIS distance query not implemented yet.
        // Android falls back to fetching all active outlets.
        let dtos: [OutletDto] = try await client
            .from("outlets")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
        
        return dtos.map { $0.toDomain() }
    }
}

// MARK: - Outlet DTO → Domain Mapping

extension OutletDto {
    func toDomain() -> Outlet {
        let operatingHours = operatingHours ?? OperatingHoursDto(openTime: "08:00", closeTime: "22:00", daysOpen: ["Mon","Tue","Wed","Thu","Fri"])
        
        return Outlet(
            id: id,
            name: name,
            description: description,
            imageUrl: imageUrl,
            location: OutletLocation(
                building: building ?? "",
                floor: floor ?? "",
                description: locationDescription ?? "",
                latitude: latitude,
                longitude: longitude
            ),
            isOpen: isOpen,
            operatingHours: OperatingHours(
                openTime: operatingHours.openTime,
                closeTime: operatingHours.closeTime,
                daysOpen: operatingHours.daysOpen
            ),
            currentQueueSize: 0,  // Not in schema - Android also defaults to 0
            estimatedWaitMinutes: 0,  // Not in schema - Android also defaults to 0
            categories: [],  // Not in schema - junction table not used
            rating: rating,
            totalReviews: totalReviews,
            vendorId: vendorId ?? "",
            isActive: isActive,
            phone: phone
        )
    }
}

// MARK: - Local Cache Protocol (protocol for testability)

protocol OutletLocalCache: Sendable {
    func observeOutlets() -> AsyncStream<[Outlet]>
    func getOutletById(_ id: String) async -> Outlet?
    func saveOutlet(_ outlet: Outlet) async throws
    func saveOutlets(_ outlets: [Outlet]) async throws
}
