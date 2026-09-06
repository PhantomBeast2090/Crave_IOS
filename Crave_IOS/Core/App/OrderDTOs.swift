import Foundation

// MARK: - Generic tolerant-decoding helpers

nonisolated func dtoString<Key: CodingKey>(_ c: KeyedDecodingContainer<Key>, _ key: Key, defaultValue: String = "") -> String {
    let v: String? = try? c.decodeIfPresent(String.self, forKey: key)
    return v ?? defaultValue
}

nonisolated func dtoOptString<Key: CodingKey>(_ c: KeyedDecodingContainer<Key>, _ key: Key) -> String? {
    try? c.decodeIfPresent(String.self, forKey: key)
}

nonisolated func dtoDouble<Key: CodingKey>(_ c: KeyedDecodingContainer<Key>, _ key: Key, defaultValue: Double = 0) -> Double {
    let d: Double? = try? c.decodeIfPresent(Double.self, forKey: key)
    if let d { return d }
    let i: Int? = try? c.decodeIfPresent(Int.self, forKey: key)
    if let i { return Double(i) }
    let s: String? = try? c.decodeIfPresent(String.self, forKey: key)
    if let s, let d = Double(s) { return d }
    return defaultValue
}

nonisolated func dtoInt<Key: CodingKey>(_ c: KeyedDecodingContainer<Key>, _ key: Key, defaultValue: Int = 0) -> Int {
    let v: Int? = try? c.decodeIfPresent(Int.self, forKey: key)
    if let v { return v }
    let d: Double? = try? c.decodeIfPresent(Double.self, forKey: key)
    if let d { return Int(d) }
    let s: String? = try? c.decodeIfPresent(String.self, forKey: key)
    if let s, let i = Int(s) { return i }
    if let s, let d = Double(s) { return Int(d) }
    return defaultValue
}

nonisolated func dtoBool<Key: CodingKey>(_ c: KeyedDecodingContainer<Key>, _ key: Key, defaultValue: Bool = false) -> Bool {
    (try? c.decodeIfPresent(Bool.self, forKey: key)) ?? defaultValue
}

/// Postgres TIME arrives as "HH:mm:ss" — display trims to "HH:mm".
nonisolated func shortTime(_ raw: String) -> String {
    raw.count >= 5 ? String(raw.prefix(5)) : raw
}

// MARK: - Pickup Slot DTO

nonisolated struct PickupSlotDto: Decodable, Sendable {
    let id: String
    let outletId: String
    let date: String
    let startTime: String
    let endTime: String
    let capacity: Int
    let bookedCount: Int
    let status: SlotStatus

    enum CodingKeys: String, CodingKey {
        case id, capacity, status
        case outletId = "outlet_id"
        case date = "slot_date"
        case startTime = "start_time"
        case endTime = "end_time"
        case bookedCount = "booked_count"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        outletId = dtoString(c, .outletId)
        date = dtoString(c, .date)
        startTime = shortTime(dtoString(c, .startTime))
        endTime = shortTime(dtoString(c, .endTime))
        capacity = dtoInt(c, .capacity)
        bookedCount = dtoInt(c, .bookedCount)
        status = SlotStatus(fromString: dtoString(c, .status, defaultValue: "AVAILABLE"))
    }

    func toDomain() -> PickupSlot {
        PickupSlot(id: id, outletId: outletId, startTime: startTime, endTime: endTime,
                   date: date, capacity: capacity, bookedCount: bookedCount, status: status)
    }
}

// MARK: - Order DTOs
//
// Query shape: `*, outlets(name), pickup_slots(*), items:order_items(*,
// order_item_customizations(*))`. Decoders accept both aliased (`items`) and
// raw (`order_items`) keys, plus a flat `outlet_name` fallback.

nonisolated struct OrderItemCustomizationDto: Decodable, Sendable {
    let variantName: String
    let optionName: String
    let extraPrice: Double

    enum CodingKeys: String, CodingKey {
        case variantName = "variant_name"
        case optionName = "option_name"
        case extraPrice = "extra_price"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        variantName = dtoString(c, .variantName)
        optionName = dtoString(c, .optionName)
        extraPrice = dtoDouble(c, .extraPrice)
    }

    var displayString: String { "\(variantName): \(optionName)" }
}

nonisolated struct OrderItemDto: Decodable, Sendable {
    let id: String
    let foodItemId: String
    let foodName: String
    let foodImageUrl: String?
    let quantity: Int
    let unitPrice: Double
    let totalPrice: Double
    let customizations: [OrderItemCustomizationDto]
    let isVeg: Bool

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case foodItemId = "food_item_id"
        case foodName = "food_name"
        case foodImageUrl = "food_image_url"
        case unitPrice = "unit_price"
        case totalPrice = "total_price"
        case customizations = "order_item_customizations"
        case isVeg = "is_veg"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        foodItemId = dtoString(c, .foodItemId)
        foodName = dtoString(c, .foodName, defaultValue: "Item")
        foodImageUrl = dtoOptString(c, .foodImageUrl)
        quantity = dtoInt(c, .quantity, defaultValue: 1)
        unitPrice = dtoDouble(c, .unitPrice)
        let total = dtoDouble(c, .totalPrice, defaultValue: -1)
        totalPrice = total < 0 ? unitPrice * Double(quantity) : total
        customizations = (try? c.decodeIfPresent([OrderItemCustomizationDto].self, forKey: .customizations)) ?? []
        isVeg = dtoBool(c, .isVeg, defaultValue: true)
    }

    func toDomain() -> OrderItem {
        OrderItem(id: id, foodItemId: foodItemId, foodName: foodName, foodImageUrl: foodImageUrl,
                  quantity: quantity, unitPrice: unitPrice, totalPrice: totalPrice,
                  customizations: customizations.map { $0.displayString }, isVeg: isVeg)
    }
}

nonisolated struct OrderOutletRefDto: Decodable, Sendable {
    let name: String
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
    }
    enum CodingKeys: String, CodingKey { case name }
}

nonisolated struct OrderDto: Decodable, Sendable {
    let id: String
    let orderNumber: String
    let userId: String
    let vendorId: String
    let outletId: String
    let outletName: String
    let items: [OrderItemDto]
    let subtotal: Double
    let tax: Double
    let total: Double
    let status: OrderStatus
    let pickupSlot: PickupSlotDto?
    let estimatedPrepMinutes: Int
    let actualPrepMinutes: Int?
    let createdAt: String
    let placedAt: String?
    let acceptedAt: String?
    let preparingAt: String?
    let readyAt: String?
    let pickedUpAt: String?
    let cancelledAt: String?
    let cancellationReason: String?
    let paymentStatus: PaymentStatus
    let paymentMethod: PaymentMethod
    let specialInstructions: String?
    let qrToken: String?

    enum CodingKeys: String, CodingKey {
        case id, items, subtotal, tax, total, status
        case orderNumber = "order_number"
        case userId = "user_id"
        case vendorId = "vendor_id"
        case outletId = "outlet_id"
        case outletName = "outlet_name"
        case outlets
        case rawItems = "order_items"
        case pickupSlot = "pickup_slots"
        case estimatedPrepMinutes = "estimated_prep_minutes"
        case actualPrepMinutes = "actual_prep_minutes"
        case createdAt = "created_at"
        case placedAt = "placed_at"
        case acceptedAt = "accepted_at"
        case preparingAt = "preparing_at"
        case readyAt = "ready_at"
        case pickedUpAt = "picked_up_at"
        case cancelledAt = "cancelled_at"
        case cancellationReason = "cancellation_reason"
        case paymentStatus = "payment_status"
        case paymentMethod = "payment_method"
        case specialInstructions = "special_instructions"
        case qrToken = "qr_token"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        orderNumber = dtoString(c, .orderNumber)
        userId = dtoString(c, .userId)
        vendorId = dtoString(c, .vendorId)
        outletId = dtoString(c, .outletId)
        if let nested = try? c.decodeIfPresent(OrderOutletRefDto.self, forKey: .outlets) {
            outletName = nested.name
        } else {
            outletName = dtoString(c, .outletName)
        }
        if let aliased = try? c.decodeIfPresent([OrderItemDto].self, forKey: .items) {
            items = aliased ?? []
        } else {
            items = (try? c.decodeIfPresent([OrderItemDto].self, forKey: .rawItems)) ?? []
        }
        subtotal = dtoDouble(c, .subtotal)
        tax = dtoDouble(c, .tax)
        total = dtoDouble(c, .total)
        status = OrderStatus(fromString: dtoString(c, .status, defaultValue: "CREATED"))
        pickupSlot = try? c.decodeIfPresent(PickupSlotDto.self, forKey: .pickupSlot)
        estimatedPrepMinutes = dtoInt(c, .estimatedPrepMinutes)
        actualPrepMinutes = {
            let v: Int? = try? c.decodeIfPresent(Int.self, forKey: .actualPrepMinutes)
            return v
        }()
        createdAt = dtoString(c, .createdAt)
        placedAt = dtoOptString(c, .placedAt)
        acceptedAt = dtoOptString(c, .acceptedAt)
        preparingAt = dtoOptString(c, .preparingAt)
        readyAt = dtoOptString(c, .readyAt)
        pickedUpAt = dtoOptString(c, .pickedUpAt)
        cancelledAt = dtoOptString(c, .cancelledAt)
        cancellationReason = dtoOptString(c, .cancellationReason)
        paymentStatus = PaymentStatus(fromString: dtoString(c, .paymentStatus, defaultValue: "PENDING"))
        paymentMethod = PaymentMethod(fromString: dtoString(c, .paymentMethod, defaultValue: "PAY_AT_COUNTER"))
        specialInstructions = dtoOptString(c, .specialInstructions)
        qrToken = dtoOptString(c, .qrToken)
    }

    func toDomain() -> Order {
        Order(id: id, orderNumber: orderNumber, userId: userId, vendorId: vendorId,
              outletId: outletId, outletName: outletName,
              items: items.map { $0.toDomain() },
              subtotal: subtotal, tax: tax, total: total, status: status,
              pickupSlot: pickupSlot?.toDomain(),
              estimatedPrepMinutes: estimatedPrepMinutes, actualPrepMinutes: actualPrepMinutes,
              createdAt: createdAt, placedAt: placedAt, acceptedAt: acceptedAt,
              preparingAt: preparingAt, readyAt: readyAt, pickedUpAt: pickedUpAt,
              cancelledAt: cancelledAt, cancellationReason: cancellationReason,
              paymentStatus: paymentStatus, paymentMethod: paymentMethod,
              specialInstructions: specialInstructions, qrToken: qrToken)
    }
}

// MARK: - RPC params / results

nonisolated struct PlaceOrderParams: Encodable, Sendable {
    let cartId: String
    let pickupSlotId: String
    let paymentMethod: String

    enum CodingKeys: String, CodingKey {
        case cartId = "p_cart_id"
        case pickupSlotId = "p_pickup_slot_id"
        case paymentMethod = "p_payment_method"
    }
}

nonisolated struct OrderIdParams: Encodable, Sendable {
    let orderId: String
    enum CodingKeys: String, CodingKey {
        case orderId = "p_order_id"
    }
}

nonisolated struct RejectOrderParams: Encodable, Sendable {
    let orderId: String
    let reason: String
    enum CodingKeys: String, CodingKey {
        case orderId = "p_order_id"
        case reason = "p_reason"
    }
}

nonisolated struct CancelOrderUpdate: Encodable, Sendable {
    let status: String
    let cancellationReason: String
    enum CodingKeys: String, CodingKey {
        case status
        case cancellationReason = "cancellation_reason"
    }
}

nonisolated struct VerifyPickupTokenParams: Encodable, Sendable {
    let token: String
    enum CodingKeys: String, CodingKey {
        case token = "p_token"
    }
}

nonisolated struct VerifyPickupTokenResult: Decodable, Sendable {
    let success: Bool
    let orderId: String
    let orderNumber: String
    let pickedUpAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case orderId = "order_id"
        case orderNumber = "order_number"
        case pickedUpAt = "picked_up_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? false
        // order_id arrives as UUID string.
        let rawOrderId: String? = try? c.decodeIfPresent(String.self, forKey: .orderId)
        orderId = rawOrderId ?? ""
        orderNumber = dtoString(c, .orderNumber)
        pickedUpAt = dtoOptString(c, .pickedUpAt)
    }
}

nonisolated struct PickupTokenRow: Decodable, Sendable {
    let tokenValue: String
    let expiresAt: String?
    let isUsed: Bool

    enum CodingKeys: String, CodingKey {
        case tokenValue = "token_value"
        case expiresAt = "expires_at"
        case isUsed = "is_used"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tokenValue = dtoString(c, .tokenValue)
        expiresAt = dtoOptString(c, .expiresAt)
        isUsed = dtoBool(c, .isUsed)
    }
}

// MARK: - Notification DTO

nonisolated struct NotificationDto: Decodable, Sendable {
    let id: String
    let title: String
    let body: String
    let type: NotificationType
    let orderId: String?
    let isRead: Bool
    let deepLink: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, body, type
        case orderId = "order_id"
        case isRead = "is_read"
        case deepLink = "deep_link"
        case createdAt = "created_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = dtoString(c, .title, defaultValue: "Notification")
        body = dtoString(c, .body)
        type = NotificationType(fromString: dtoString(c, .type, defaultValue: "GENERAL"))
        orderId = dtoOptString(c, .orderId)
        isRead = dtoBool(c, .isRead)
        deepLink = dtoOptString(c, .deepLink)
        createdAt = dtoString(c, .createdAt)
    }

    func toDomain() -> AppNotification {
        AppNotification(id: id, title: title, body: body, type: type, orderId: orderId,
                        isRead: isRead, deepLink: deepLink, createdAt: createdAt)
    }
}

// MARK: - Admin DTOs

/// `get_admin_stats()` returns camelCase JSON (see migration 009 — it reads
/// `profiles`, so no backend issue here).
nonisolated struct SystemStats: Decodable, Sendable, Hashable {
    let totalUsers: Int
    let totalVendors: Int
    let totalOutlets: Int
    let totalOrders: Int
    let activeOrders: Int
    let completedOrders: Int
    let revenue: Double
    let ordersToday: Int
    let revenueToday: Double

    enum CodingKeys: String, CodingKey {
        case totalUsers, totalVendors, totalOutlets, totalOrders
        case activeOrders, completedOrders, revenue, ordersToday, revenueToday
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalUsers = dtoInt(c, .totalUsers)
        totalVendors = dtoInt(c, .totalVendors)
        totalOutlets = dtoInt(c, .totalOutlets)
        totalOrders = dtoInt(c, .totalOrders)
        activeOrders = dtoInt(c, .activeOrders)
        completedOrders = dtoInt(c, .completedOrders)
        revenue = dtoDouble(c, .revenue)
        ordersToday = dtoInt(c, .ordersToday)
        revenueToday = dtoDouble(c, .revenueToday)
    }
}

nonisolated struct ToggleOutletStatusParams: Encodable, Sendable {
    let outletId: String
    let isOpen: Bool
    enum CodingKeys: String, CodingKey {
        case outletId = "p_outlet_id"
        case isOpen = "p_is_open"
    }
}

// MARK: - Payment edge-function DTOs

nonisolated struct CreateRazorpayOrderRequest: Encodable, Sendable {
    let orderId: String
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
    }
}
