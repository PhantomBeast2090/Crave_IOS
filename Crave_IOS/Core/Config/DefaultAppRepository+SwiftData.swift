import Foundation
import Supabase
import SwiftData

/// Factory to create repository with SwiftData persistence
final class SwiftDataAppRepositoryFactory {
    static func make(modelContainer: ModelContainer) -> AppRepository {
        // Shared client — a second SupabaseClient would lose the auth session.
        let client = SupabaseClientProvider.shared

        let outletCache = SwiftDataOutletCache(modelContainer: modelContainer)
        let foodCache = SwiftDataFoodCache(modelContainer: modelContainer)
        let cartStore = SwiftDataCartStore(modelContainer: modelContainer)

        let outlets = SupabaseOutletRepository(client: client, localCache: outletCache)
        let food = SupabaseFoodRepository(client: client, auth: client.auth, localCache: foodCache)
        let cart = SupabaseCartRepository(client: client, store: cartStore)
        let orders = SupabaseOrderRepository(client: client, modelContainer: modelContainer)
        let notifications = SupabaseNotificationRepository(client: client)
        let payments = SupabasePaymentRepository(client: client)
        let admin = SupabaseAdminRepository(client: client)

        return DefaultAppRepository(outlets: outlets, food: food, cart: cart,
                                    orders: orders, notifications: notifications,
                                    payments: payments, admin: admin)
    }
}
