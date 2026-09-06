import Foundation
import Supabase
import SwiftData

/// Order + slot + vendor repository. Backend is authoritative for everything;
/// SwiftData `OrderEntity` rows are only an offline cache.
@MainActor
final class SupabaseOrderRepository: OrderRepository, Sendable {
    private let client: SupabaseClient
    private let modelContainer: ModelContainer?
    private var latestNetwork: [Order] = []
    private var orderContinuations: [UUID: AsyncStream<[Order]>.Continuation] = [:]

    /// `outlets(name)` gives a stable key; `items:` aliases the order_items
    /// embed so decoding doesn't depend on table names.
    static let orderColumns = "*, outlets(name), pickup_slots(*), items:order_items(*, order_item_customizations(*))"

    init(client: SupabaseClient = SupabaseClientProvider.shared, modelContainer: ModelContainer? = nil) {
        self.client = client
        self.modelContainer = modelContainer
    }

    private var userId: String? { client.auth.currentSession?.user.id.uuidString }

    // MARK: - Cache

    private func loadCachedOrders() -> [Order] {
        guard let modelContainer else { return latestNetwork }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<OrderEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toDomain() }
    }

    private func replaceCache(with orders: [Order]) {
        latestNetwork = orders
        guard let modelContainer else {
            notifyOrdersChanged()
            return
        }
        let context = ModelContext(modelContainer)
        do {
            for existing in (try? context.fetch(FetchDescriptor<OrderEntity>())) ?? [] {
                context.delete(existing)
            }
            for order in orders {
                let (entity, _) = order.toEntity()
                context.insert(entity)
            }
            try context.save()
        } catch {
            print("⚠️ [Orders] cache write failed: \(error)")
        }
        notifyOrdersChanged()
    }

    private func upsertCache(_ order: Order) {
        if let index = latestNetwork.firstIndex(where: { $0.id == order.id }) {
            latestNetwork[index] = order
        } else {
            latestNetwork.insert(order, at: 0)
        }
        guard let modelContainer else {
            notifyOrdersChanged()
            return
        }
        let context = ModelContext(modelContainer)
        do {
            let orderId = order.id
            let descriptor = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == orderId })
            for existing in (try? context.fetch(descriptor)) ?? [] {
                context.delete(existing)
            }
            let (entity, _) = order.toEntity()
            context.insert(entity)
            try context.save()
        } catch {
            print("⚠️ [Orders] cache write failed: \(error)")
        }
        notifyOrdersChanged()
    }

    private func notifyOrdersChanged() {
        let orders = loadCachedOrders()
        for continuation in orderContinuations.values {
            continuation.yield(orders)
        }
    }

    func observeOrders() -> AsyncStream<[Order]> {
        AsyncStream { continuation in
            let id = UUID()
            orderContinuations[id] = continuation
            continuation.yield(loadCachedOrders())
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in self?.orderContinuations.removeValue(forKey: id) }
            }
        }
    }

    func activeOrder() async -> Order? {
        loadCachedOrders().first(where: { $0.status.isActive })
    }

    // MARK: - Student reads

    func refreshOrders() async throws -> [Order] {
        guard let uid = userId else { return loadCachedOrders() }
        let dtos: [OrderDto]
        do {
            dtos = try await client.from("orders")
                .select(Self.orderColumns)
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("❌ [Orders] refresh failed: \(describeDecodingError(error))")
            let cached = loadCachedOrders()
            if cached.isEmpty { throw AppError.message("Couldn't load orders: \(describeDecodingError(error))") }
            return cached
        }
        let orders = dtos.map { $0.toDomain() }
        replaceCache(with: orders)
        return orders
    }

    func getOrderById(_ orderId: String) async throws -> Order {
        let dto: OrderDto
        do {
            dto = try await client.from("orders")
                .select(Self.orderColumns)
                .eq("id", value: orderId)
                .single()
                .execute()
                .value
        } catch {
            print("❌ [Orders] getOrderById failed: \(describeDecodingError(error))")
            throw AppError.message("Couldn't load order: \(describeDecodingError(error))")
        }
        let order = dto.toDomain()
        upsertCache(order)
        return order
    }

    // MARK: - Slots

    func getPickupSlots(outletId: String, date: String) async throws -> [PickupSlot] {
        let dtos: [PickupSlotDto]
        do {
            dtos = try await client.from("pickup_slots")
                .select()
                .eq("outlet_id", value: outletId)
                .eq("slot_date", value: date)
                .execute()
                .value
        } catch {
            print("❌ [Orders] slots failed: \(describeDecodingError(error))")
            throw AppError.message("Couldn't load pickup slots: \(describeDecodingError(error))")
        }
        return dtos.map { $0.toDomain() }.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Placement

    func backendCartId() async throws -> String {
        guard let uid = userId else { throw CartError.notSignedIn }
        struct CartIdRow: Decodable, Sendable { let id: String }
        let rows: [CartIdRow] = (try? await client.from("carts")
            .select("id")
            .eq("user_id", value: uid)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value) ?? []
        guard let id = rows.first?.id else { throw CartError.emptyCart }
        return id
    }

    func placeOrder(pickupSlotId: String, paymentMethod: PaymentMethod) async throws -> Order {
        let cartId = try await backendCartId()
        let orderId: String
        do {
            orderId = try await client
                .rpc("place_order", params: PlaceOrderParams(
                    cartId: cartId,
                    pickupSlotId: pickupSlotId,
                    paymentMethod: paymentMethod.rawValue
                ))
                .execute()
                .value
        } catch {
            print("❌ [Orders] place_order failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Couldn't place order. Please try again.")
        }
        return try await getOrderById(orderId)
    }

    func cancelOrder(orderId: String, reason: String) async throws -> Order {
        do {
            try await client.from("orders")
                .update(CancelOrderUpdate(status: "CANCELLED", cancellationReason: reason))
                .eq("id", value: orderId)
                .execute()
        } catch {
            print("❌ [Orders] cancel failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Couldn't cancel order.")
        }
        return try await getOrderById(orderId)
    }

    // MARK: - Pickup token

    func getPickupToken(orderId: String) async throws -> (token: String, expiresAt: String?) {
        let rows: [PickupTokenRow]
        do {
            rows = try await client.from("pickup_tokens")
                .select("token_value, expires_at, is_used")
                .eq("order_id", value: orderId)
                .execute()
                .value
        } catch {
            throw AppError.message("Couldn't load pickup token: \(describeDecodingError(error))")
        }
        guard let row = rows.first, !row.tokenValue.isEmpty else {
            throw AppError.message("Pickup token is not available yet.")
        }
        if row.isUsed { throw AppError.message("This pickup token has already been used.") }
        return (row.tokenValue, row.expiresAt)
    }

    // MARK: - Realtime status

    func observeOrderStatus(orderId: String) -> AsyncStream<OrderStatus> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                if let cached = self.loadCachedOrders().first(where: { $0.id == orderId }) {
                    continuation.yield(cached.status)
                }
                let channel = self.client.realtimeV2.channel("order-\(orderId)")
                let updates = channel.postgresChange(
                    UpdateAction.self,
                    schema: "public",
                    table: "orders",
                    filter: .eq("id", value: orderId)
                )
                do {
                    try await channel.subscribe()
                } catch {
                    print("⚠️ [Orders] realtime subscribe failed: \(error)")
                    continuation.finish()
                    return
                }
                for await action in updates {
                    if Task.isCancelled { break }
                    if let raw = action.record["status"]?.stringValue, !raw.isEmpty {
                        let status = OrderStatus(fromString: raw)
                        continuation.yield(status)
                        // Patch the cache so history/detail stay consistent.
                        self.patchCachedStatus(orderId: orderId, status: status)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func patchCachedStatus(orderId: String, status: OrderStatus) {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)
        do {
            let descriptor = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == orderId })
            if let entity = try context.fetch(descriptor).first {
                entity.status = status
                try context.save()
                notifyOrdersChanged()
            }
        } catch {
            print("⚠️ [Orders] cache patch failed: \(error)")
        }
    }

    // MARK: - Vendor

    func getVendorOrders(status: OrderStatus?) async throws -> [Order] {
        guard userId != nil else { throw CartError.notSignedIn }
        // Vendor scoping is enforced server-side (RLS + RPC ownership checks);
        // `vendor_id` here only narrows our own client's query.
        guard let vendorId = client.auth.currentSession?.user.id.uuidString else {
            throw CartError.notSignedIn
        }
        do {
            var query = client.from("orders").select(Self.orderColumns).eq("vendor_id", value: vendorId)
            if let status {
                query = query.eq("status", value: status.rawValue)
            }
            let dtos: [OrderDto] = try await query
                .order("created_at", ascending: false)
                .execute()
                .value
            return dtos.map { $0.toDomain() }
        } catch {
            print("❌ [Orders] vendor orders failed: \(describeDecodingError(error))")
            throw AppError.message("Couldn't load vendor orders: \(describeDecodingError(error))")
        }
    }

    private func vendorTransition(rpc: String, orderId: String, reason: String? = nil) async throws -> Order {
        do {
            if let reason {
                try await client.rpc(rpc, params: RejectOrderParams(orderId: orderId, reason: reason)).execute()
            } else {
                try await client.rpc(rpc, params: OrderIdParams(orderId: orderId)).execute()
            }
        } catch {
            print("❌ [Orders] \(rpc) failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Action failed. Please try again.")
        }
        return try await getOrderById(orderId)
    }

    func acceptOrder(orderId: String) async throws -> Order {
        try await vendorTransition(rpc: "vendor_accept_order", orderId: orderId)
    }

    func rejectOrder(orderId: String, reason: String) async throws -> Order {
        try await vendorTransition(rpc: "vendor_reject_order", orderId: orderId, reason: reason)
    }

    func startPreparing(orderId: String) async throws -> Order {
        try await vendorTransition(rpc: "vendor_start_preparing", orderId: orderId)
    }

    func markReady(orderId: String) async throws -> Order {
        try await vendorTransition(rpc: "vendor_mark_ready", orderId: orderId)
    }

    func confirmPickup(qrToken: String) async throws -> Order {
        let result: VerifyPickupTokenResult
        do {
            result = try await client
                .rpc("verify_pickup_token", params: VerifyPickupTokenParams(token: qrToken))
                .execute()
                .value
        } catch {
            print("❌ [Orders] verify_pickup_token failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Token verification failed.")
        }
        guard result.success, !result.orderId.isEmpty else {
            throw AppError.message("Token verification failed.")
        }
        return try await getOrderById(result.orderId)
    }
}

// MARK: - PostgREST error message extraction
/// Pull the server-provided message (e.g. "Pickup slot is full.") out of a
/// PostgREST/RPC failure so the UI shows backend wording, not HTTP codes.
nonisolated func parsePostgrestMessage(_ error: Error) -> String? {
    let description = String(describing: error)
    // supabase-swift surfaces PostgrestError with `message` in its description.
    if let range = description.range(of: #"message: ""#, options: .regularExpression) {
        let rest = description[range.upperBound...]
        if let end = rest.firstIndex(of: "\"") {
            let message = String(rest[..<end])
            if !message.isEmpty { return message }
        }
    }
    if description.contains("CancellationError") { return nil }
    return nil
}

// MARK: - ISO8601 helpers

nonisolated func parseServerDate(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFraction.date(from: raw) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    if let d = plain.date(from: raw) { return d }
    // Fallback: plain "yyyy-MM-dd".
    let day = DateFormatter()
    day.locale = Locale(identifier: "en_US_POSIX")
    day.dateFormat = "yyyy-MM-dd"
    return day.date(from: raw)
}

nonisolated func serverDateString(_ date: Date?) -> String? {
    guard let date else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.string(from: date)
}

// MARK: - OrderEntity <-> Order mapping

extension OrderEntity {
    func toDomain() -> Order {
        Order(
            id: id,
            orderNumber: orderNumber,
            userId: userId,
            vendorId: vendorId,
            outletId: outletId,
            outletName: outletName,
            items: items.map { item in
                OrderItem(id: item.id, foodItemId: item.foodItemId, foodName: item.foodName,
                          foodImageUrl: item.foodImageUrl, quantity: item.quantity,
                          unitPrice: item.unitPrice, totalPrice: item.totalPrice,
                          customizations: item.customizations, isVeg: item.isVeg)
            },
            subtotal: subtotal, tax: tax, total: total, status: status,
            pickupSlot: {
                guard let d = slotDate, let s = slotStartTime, let e = slotEndTime else { return nil }
                return PickupSlot(id: "", outletId: outletId, startTime: s, endTime: e,
                                  date: d, capacity: 0, bookedCount: 0, status: .available)
            }(),
            estimatedPrepMinutes: estimatedPrepMinutes, actualPrepMinutes: actualPrepMinutes,
            createdAt: serverDateString(createdAt) ?? "", placedAt: serverDateString(placedAt),
            acceptedAt: serverDateString(acceptedAt), preparingAt: serverDateString(preparingAt),
            readyAt: serverDateString(readyAt), pickedUpAt: serverDateString(pickedUpAt),
            cancelledAt: serverDateString(cancelledAt), cancellationReason: cancellationReason,
            paymentStatus: paymentStatus, paymentMethod: paymentMethod,
            specialInstructions: specialInstructions, qrToken: qrToken
        )
    }
}

extension Order {
    func toEntity() -> (OrderEntity, [OrderItemEntity]) {
        let itemEntities = items.map { item in
            OrderItemEntity(id: item.id, foodItemId: item.foodItemId, foodName: item.foodName,
                            foodImageUrl: item.foodImageUrl, quantity: item.quantity,
                            unitPrice: item.unitPrice, totalPrice: item.totalPrice,
                            customizations: item.customizations, isVeg: item.isVeg)
        }
        let entity = OrderEntity(
            id: id, orderNumber: orderNumber, userId: userId, vendorId: vendorId,
            outletId: outletId, outletName: outletName, items: itemEntities,
            subtotal: subtotal, tax: tax, total: total, status: status,
            slotDate: pickupSlot?.date, slotStartTime: pickupSlot?.startTime,
            slotEndTime: pickupSlot?.endTime, estimatedPrepMinutes: estimatedPrepMinutes,
            actualPrepMinutes: actualPrepMinutes, paymentStatus: paymentStatus,
            paymentMethod: paymentMethod, specialInstructions: specialInstructions, qrToken: qrToken
        )
        entity.createdAt = parseServerDate(createdAt) ?? Date()
        entity.placedAt = parseServerDate(placedAt)
        entity.acceptedAt = parseServerDate(acceptedAt)
        entity.preparingAt = parseServerDate(preparingAt)
        entity.readyAt = parseServerDate(readyAt)
        entity.pickedUpAt = parseServerDate(pickedUpAt)
        entity.cancelledAt = parseServerDate(cancelledAt)
        return (entity, itemEntities)
    }
}
