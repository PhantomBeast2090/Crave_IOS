import Foundation
import SwiftData
import Supabase

struct DefaultAppRepository: AppRepository, Sendable {
    let outlets: OutletRepository
    let food: FoodRepository

    init(outlets: OutletRepository, food: FoodRepository) {
        self.outlets = outlets
        self.food = food
    }

    static func makeWithSwiftData(modelContainer: ModelContainer) -> DefaultAppRepository {
        let client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )

        let outletCache = SwiftDataOutletCache(modelContainer: modelContainer)
        let foodCache = SwiftDataFoodCache(modelContainer: modelContainer)

        let outlets = SupabaseOutletRepository(client: client, localCache: outletCache)
        let food = SupabaseFoodRepository(client: client, auth: client.auth, localCache: foodCache)

        return DefaultAppRepository(outlets: outlets, food: food)
    }

    static func makeInMemory() -> DefaultAppRepository {
        let client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )

        let outletCache = InMemoryOutletCache()
        let foodCache = InMemoryFoodCache()

        let outlets = SupabaseOutletRepository(client: client, localCache: outletCache)
        let food = SupabaseFoodRepository(client: client, auth: client.auth, localCache: foodCache)

        return DefaultAppRepository(outlets: outlets, food: food)
    }
}
