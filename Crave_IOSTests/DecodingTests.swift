import XCTest
@testable import Crave_IOS

/// Wire-format tolerance tests. Every payload below mirrors a real backend
/// shape (see supabase/migrations): default camelCase `operating_hours`,
/// flat `search_food` rows, aliased and raw PostgREST embeds, numeric
/// columns arriving as numbers. None of these may throw.
final class DecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: - Outlets

    func testOutletDecodesWithCamelCaseOperatingHours() throws {
        let dto = try decode(OutletDto.self, """
        {"id":"o1","name":"Main","description":"Canteen","is_open":true,"is_active":true,
         "operating_hours":{"openTime":"08:00","closeTime":"22:00","daysOpen":["Mon"]},
         "rating":4.5,"total_reviews":10}
        """)
        XCTAssertEqual(dto.toDomain().operatingHours.openTime, "08:00")
        XCTAssertEqual(dto.toDomain().operatingHours.daysOpen, ["Mon"])
        XCTAssertEqual(dto.rating, 4.5, accuracy: 0.001)
    }

    func testOutletDecodesWithSnakeCaseOperatingHours() throws {
        let dto = try decode(OutletDto.self, """
        {"id":"o1","name":"Main","description":"Canteen","is_open":false,"is_active":true,
         "operating_hours":{"open_time":"09:00","close_time":"21:00","days_open":["Tue"]},
         "rating":"4.0","total_reviews":3}
        """)
        // rating arrives as a string (Postgres DECIMAL) — must still decode.
        XCTAssertEqual(dto.rating, 4.0, accuracy: 0.001)
        XCTAssertEqual(dto.toDomain().operatingHours.closeTime, "21:00")
    }

    func testOutletSurvivesMissingKeys() throws {
        let dto = try decode(OutletDto.self, #"{"id":"o1","name":"Main"}"#)
        let outlet = dto.toDomain()
        XCTAssertEqual(outlet.description, "")
        XCTAssertEqual(outlet.operatingHours.openTime, "08:00")
        XCTAssertTrue(outlet.isActive)
    }

    // MARK: - Food

    func testFoodDecodesFlatSearchRpcShape() throws {
        // search_food returns no variants/tags/calories/total_reviews.
        let dto = try decode(FoodItemDto.self, """
        {"id":"f1","name":"Momos","description":"Steamed","price":99,
         "outlet_id":"o1","outlet_name":"Main","category_id":"c1","category_name":"Snacks",
         "is_veg":true,"is_available":true,"prep_time_minutes":10,
         "is_popular":false,"is_recommended":false,"rating":4.2}
        """)
        XCTAssertEqual(dto.outletId, "o1")
        XCTAssertEqual(dto.toDomain(favoriteIds: []).outletName, "Main")
        XCTAssertEqual(dto.toDomain(favoriteIds: []).category, "Snacks")
        XCTAssertEqual(dto.totalReviews, 0)
        XCTAssertTrue(dto.variants == nil)
    }

    func testFoodDecodesAliasedEmbeds() throws {
        let dto = try decode(FoodItemDto.self, """
        {"id":"f1","name":"Biryani","description":"Spicy","price":"149.5",
         "outlet_id":"o1","category_id":"c1","is_veg":true,"is_available":true,
         "prep_time_minutes":15,"is_popular":true,"is_recommended":false,
         "rating":4.8,"total_reviews":25,
         "outlet":{"name":"Main"},"category":{"name":"Meals","emoji":"🍛"},
         "variants":[{"id":"v1","name":"Size","is_required":true,"max_selections":1,
           "options":[{"id":"s1","name":"Large","extra_price":30}]}]}
        """)
        XCTAssertEqual(dto.price, 149.5, accuracy: 0.001)
        let domain = dto.toDomain(favoriteIds: ["f1"])
        XCTAssertTrue(domain.isFavorite)
        XCTAssertEqual(domain.customizations.count, 1)
        XCTAssertEqual(domain.customizations.first?.options.first?.extraPrice, 30)
    }

    func testFoodDecodesRawTableKeyEmbeds() throws {
        // Unaliased query: outlets/categories/food_variants/food_variant_options.
        let dto = try decode(FoodItemDto.self, """
        {"id":"f1","name":"Dosa","description":"Crisp","price":79,
         "outlet_id":"o1","category_id":"c1","is_available":true,
         "prep_time_minutes":8,"is_popular":false,"is_recommended":false,"rating":4.0,
         "outlets":{"name":"South"},"categories":{"name":"Breakfast","emoji":"🥞"},
         "food_variants":[{"id":"v1","name":"Ghee","is_required":false,"max_selections":2,
           "food_variant_options":[{"id":"g1","name":"Extra Ghee","extra_price":15}]}]}
        """)
        let domain = dto.toDomain(favoriteIds: [])
        XCTAssertEqual(domain.outletName, "South")
        XCTAssertEqual(domain.customizations.first?.options.first?.name, "Extra Ghee")
    }

    func testCategoryDecodes() throws {
        let dto = try decode(CategoryDto.self, #"{"id":"c1","name":"Snacks","emoji":"🍟"}"#)
        XCTAssertEqual(dto.emoji, "🍟")
    }

    // MARK: - Orders

    func testOrderDecodesFullShape() throws {
        let dto = try decode(OrderDto.self, """
        {"id":"ord1","order_number":"GAG-20240115-ABC123","user_id":"u1","vendor_id":"v1",
         "outlet_id":"o1","subtotal":200,"tax":10,"total":210,"status":"READY",
         "estimated_prep_minutes":15,"created_at":"2024-01-15T12:30:00+00:00",
         "payment_status":"PENDING","payment_method":"PAY_AT_COUNTER",
         "outlets":{"name":"Main"},
         "pickup_slots":{"id":"s1","outlet_id":"o1","slot_date":"2024-01-15",
           "start_time":"12:30:00","end_time":"12:40:00","capacity":20,"booked_count":5,"status":"LIMITED"},
         "items":[{"id":"oi1","food_item_id":"f1","food_name":"Biryani","quantity":2,
           "unit_price":100,"total_price":200,"is_veg":true,
           "order_item_customizations":[{"variant_name":"Size","option_name":"Large","extra_price":0}]}]}
        """)
        let order = dto.toDomain()
        XCTAssertEqual(order.status, .ready)
        XCTAssertEqual(order.outletName, "Main")
        XCTAssertEqual(order.pickupSlot?.displayTime, "12:30 – 12:40")
        XCTAssertEqual(order.items.first?.customizations, ["Size: Large"])
        XCTAssertEqual(order.paymentMethod, .payAtCounter)
    }

    func testOrderSurvivesMinimalShape() throws {
        let dto = try decode(OrderDto.self, #"{"id":"ord1","status":"weird_status"}"#)
        XCTAssertEqual(dto.status, .created) // unknown statuses fall back safely
        XCTAssertTrue(dto.items.isEmpty)
    }

    // MARK: - Notifications / admin / enums

    func testNotificationDecodes() throws {
        let dto = try decode(NotificationDto.self, """
        {"id":"n1","title":"Ready","body":"Pickup now","type":"ORDER_READY",
         "order_id":"ord1","is_read":false,"created_at":"2024-01-15T12:30:00+00:00"}
        """)
        XCTAssertEqual(dto.toDomain().type, .orderReady)
        XCTAssertFalse(dto.toDomain().isRead)
    }

    func testNotificationUnknownTypeFallsBackToGeneral() throws {
        let dto = try decode(NotificationDto.self, #"{"id":"n1","title":"t","body":"b","type":"PICKUP_REMINDER"}"#)
        // PICKUP_REMINDER is server-only; domain has no such case.
        XCTAssertEqual(dto.type, .general)
    }

    func testSystemStatsDecodesCamelCase() throws {
        let stats = try decode(SystemStats.self, """
        {"totalUsers":10,"totalVendors":2,"totalOutlets":3,"totalOrders":50,
         "activeOrders":5,"completedOrders":40,"revenue":12000.5,"ordersToday":4,"revenueToday":800}
        """)
        XCTAssertEqual(stats.totalUsers, 10)
        XCTAssertEqual(stats.revenue, 12000.5, accuracy: 0.001)
    }

    func testEnumMappings() {
        XCTAssertEqual(OrderStatus(fromString: "picked_up"), .pickedUp)
        XCTAssertTrue(OrderStatus.placed.isActive)
        XCTAssertTrue(OrderStatus.rejected.isTerminal)
        XCTAssertFalse(OrderStatus.created.isActive)
        XCTAssertEqual(PaymentMethod(fromString: "ONLINE"), .online)
        XCTAssertEqual(PaymentMethod(fromString: "anything-else"), .payAtCounter)
        XCTAssertTrue(PaymentStatus.paid.isSettled)
        XCTAssertTrue(PaymentStatus.captured.isSettled)
        XCTAssertFalse(PaymentStatus.pending.isSettled)
        XCTAssertEqual(SlotStatus(fromString: "FULL"), .full)
        XCTAssertTrue(PickupSlot(id: "s", outletId: "o", startTime: "12:30", endTime: "12:40",
                                 date: "2024-01-15", capacity: 20, bookedCount: 20, status: .full).isSelectable == false)
    }

    func testErrorDescriptionHelper() {
        struct Missing: Decodable { let required: String }
        do {
            _ = try JSONDecoder().decode(Missing.self, from: Data("{}".utf8))
            XCTFail("should throw")
        } catch {
            let message = describeDecodingError(error)
            XCTAssertTrue(message.contains("required"), "got: \(message)")
        }
    }
}
