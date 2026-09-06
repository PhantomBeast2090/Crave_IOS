import Foundation
import SwiftData
import Supabase

struct DefaultAppRepository: AppRepository, Sendable {
    let outlets: OutletRepository
    let food: FoodRepository
    let cart: CartRepository
    let orders: OrderRepository
    let notifications: NotificationRepository
    let payments: PaymentRepository
    let admin: AdminRepository

    init(
        outlets: OutletRepository,
        food: FoodRepository,
        cart: CartRepository,
        orders: OrderRepository,
        notifications: NotificationRepository,
        payments: PaymentRepository,
        admin: AdminRepository
    ) {
        self.outlets = outlets
        self.food = food
        self.cart = cart
        self.orders = orders
        self.notifications = notifications
        self.payments = payments
        self.admin = admin
    }

    static func makeWithSwiftData(modelContainer: ModelContainer) -> DefaultAppRepository {
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

    static func makeInMemory() -> DefaultAppRepository {
        // Shared client — a second SupabaseClient would lose the auth session.
        let client = SupabaseClientProvider.shared

        let outletCache = InMemoryOutletCache()
        let foodCache = InMemoryFoodCache()
        let cartStore = InMemoryCartStore()

        let outlets = SupabaseOutletRepository(client: client, localCache: outletCache)
        let food = SupabaseFoodRepository(client: client, auth: client.auth, localCache: foodCache)
        let cart = SupabaseCartRepository(client: client, store: cartStore)
        let notifications = SupabaseNotificationRepository(client: client)
        let payments = SupabasePaymentRepository(client: client)
        let admin = SupabaseAdminRepository(client: client)
        // No persistent store in this flavour — order history keeps the last
        // fetched results in memory.
        let orders = SupabaseOrderRepository(client: client, modelContainer: nil)

        return DefaultAppRepository(outlets: outlets, food: food, cart: cart,
                                    orders: orders, notifications: notifications,
                                    payments: payments, admin: admin)
    }
}
