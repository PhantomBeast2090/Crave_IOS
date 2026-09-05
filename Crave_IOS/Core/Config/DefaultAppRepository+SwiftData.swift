import Foundation
import Supabase
import SwiftData

/// Factory to create repository with SwiftData persistence
final class SwiftDataAppRepositoryFactory {
    static func make(modelContainer: ModelContainer) -> AppRepository {
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
}
