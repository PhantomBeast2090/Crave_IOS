import Foundation
import Supabase

// MARK: - Remote DTOs (tolerant)

private struct RemoteCartRow: Decodable, Sendable {
    let id: String
    let userId: String
    let outletId: String?
    let subtotal: Double
    let tax: Double
    let total: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case outletId = "outlet_id"
        case subtotal, tax, total
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = (try? c.decodeIfPresent(String.self, forKey: .userId)) ?? ""
        outletId = try? c.decodeIfPresent(String.self, forKey: .outletId)
        subtotal = Self.flexDouble(c, key: .subtotal)
        tax = Self.flexDouble(c, key: .tax)
        total = Self.flexDouble(c, key: .total)
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        let d: Double? = try? c.decodeIfPresent(Double.self, forKey: key)
        if let d { return d }
        let i: Int? = try? c.decodeIfPresent(Int.self, forKey: key)
        if let i { return Double(i) }
        let s: String? = try? c.decodeIfPresent(String.self, forKey: key)
        if let s, let d = Double(s) { return d }
        return 0
    }
}

private struct RemoteCartInsert: Encodable, Sendable {
    let id: String
    let userId: String
    let outletId: String?
    let subtotal: Double
    let tax: Double
    let total: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case outletId = "outlet_id"
        case subtotal, tax, total
    }
}

private struct RemoteCartTotalsUpdate: Encodable, Sendable {
    let outletId: String
    let subtotal: Double
    let tax: Double
    let total: Double

    enum CodingKeys: String, CodingKey {
        case outletId = "outlet_id"
        case subtotal, tax, total
    }
}

private struct RemoteCartItemJoin: Decodable, Sendable {
    let id: String
    let foodItemId: String
    let quantity: Int
    let price: Double
    let isVeg: Bool
    let specialInstructions: String?
    let foodName: String
    let foodImageUrl: String?
    let outletName: String

    enum CodingKeys: String, CodingKey {
        case id, quantity, price
        case foodItemId = "food_item_id"
        case isVeg = "is_veg"
        case specialInstructions = "special_instructions"
        case foodItems = "food_items"
    }

    enum FoodKeys: String, CodingKey {
        case name
        case imageUrl = "image_url"
        case outlets
    }

    enum OutletKeys: String, CodingKey {
        case name
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        foodItemId = (try? c.decodeIfPresent(String.self, forKey: .foodItemId)) ?? ""
        quantity = (try? c.decodeIfPresent(Int.self, forKey: .quantity)) ?? 1
        let d: Double? = try? c.decodeIfPresent(Double.self, forKey: .price)
        let i: Int? = try? c.decodeIfPresent(Int.self, forKey: .price)
        price = d ?? (i.map(Double.init) ?? 0)
        isVeg = (try? c.decodeIfPresent(Bool.self, forKey: .isVeg)) ?? true
        specialInstructions = try? c.decodeIfPresent(String.self, forKey: .specialInstructions)
        if let food = try? c.nestedContainer(keyedBy: FoodKeys.self, forKey: .foodItems) {
            foodName = (try? food.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown"
            foodImageUrl = try? food.decodeIfPresent(String.self, forKey: .imageUrl)
            if let outlet = try? food.nestedContainer(keyedBy: OutletKeys.self, forKey: .outlets) {
                outletName = (try? outlet.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown Outlet"
            } else {
                outletName = "Unknown Outlet"
            }
        } else {
            foodName = "Unknown"
            foodImageUrl = nil
            outletName = "Unknown Outlet"
        }
    }
}

private struct RemoteCartItemInsert: Encodable, Sendable {
    let id: String
    let cartId: String
    let foodItemId: String
    let quantity: Int
    let price: Double
    let isVeg: Bool
    let specialInstructions: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cartId = "cart_id"
        case foodItemId = "food_item_id"
        case quantity, price
        case isVeg = "is_veg"
        case specialInstructions = "special_instructions"
    }
}

private struct RemoteCustomizationRow: Decodable, Sendable {
    let cartItemId: String
    let variantId: String
    let optionId: String
    let extraPrice: Double

    enum CodingKeys: String, CodingKey {
        case cartItemId = "cart_item_id"
        case variantId = "variant_id"
        case optionId = "food_item_id"
    }

    // NOTE: actual column is `option_id`; CodingKeys above intentionally
    // lists the wire name per key — see init for tolerant handling.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: LooseKeys.self)
        func s(_ keys: String...) -> String {
            for k in keys {
                guard let key = LooseKeys(stringValue: k) else { continue }
                let v: String? = try? c.decodeIfPresent(String.self, forKey: key)
                if let v { return v }
            }
            return ""
        }
        cartItemId = s("cart_item_id")
        variantId = s("variant_id")
        optionId = s("option_id")
        let d: Double? = (try? c.decodeIfPresent(Double.self, forKey: LooseKeys(stringValue: "extra_price")!)) ?? nil
        let i: Int? = (try? c.decodeIfPresent(Int.self, forKey: LooseKeys(stringValue: "extra_price")!)) ?? nil
        extraPrice = d ?? (i.map(Double.init) ?? 0)
    }

    private struct LooseKeys: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

private struct RemoteCustomizationInsert: Encodable, Sendable {
    let cartItemId: String
    let variantId: String
    let optionId: String
    let extraPrice: Double

    enum CodingKeys: String, CodingKey {
        case cartItemId = "cart_item_id"
        case variantId = "variant_id"
        case optionId = "option_id"
        case extraPrice = "extra_price"
    }
}

private struct VariantNameRow: Decodable, Sendable {
    let id: String
    let foodItemId: String
    let name: String
    let options: [VariantOptionNameRow]?

    enum CodingKeys: String, CodingKey {
        case id, name
        case foodItemId = "food_item_id"
        case options = "food_variant_options"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        foodItemId = (try? c.decodeIfPresent(String.self, forKey: .foodItemId)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        options = try? c.decodeIfPresent([VariantOptionNameRow].self, forKey: .options)
    }
}

private struct VariantOptionNameRow: Decodable, Sendable {
    let id: String
    let name: String
    let extraPrice: Double

    enum CodingKeys: String, CodingKey {
        case id, name
        case extraPrice = "extra_price"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        let d: Double? = try? c.decodeIfPresent(Double.self, forKey: .extraPrice)
        let i: Int? = try? c.decodeIfPresent(Int.self, forKey: .extraPrice)
        extraPrice = d ?? (i.map(Double.init) ?? 0)
    }
}

// MARK: - Repository

/// Cart repository: SwiftData is the UI source of truth; the backend
/// (carts / cart_items / cart_item_customizations) is synced on every
/// mutation (best-effort) and authoritatively before checkout.
@MainActor
final class SupabaseCartRepository: CartRepository, Sendable {
    private let client: SupabaseClient
    private let store: CartLocalStore

    init(client: SupabaseClient = SupabaseClientProvider.shared, store: CartLocalStore) {
        self.client = client
        self.store = store
    }

    private var userId: String? { client.auth.currentSession?.user.id.uuidString }

    // MARK: - Reads

    func observeCart() -> AsyncStream<Cart?> {
        let entities = store.observe()
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                for await list in entities {
                    continuation.yield(Self.snapshot(from: list))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func currentCart() async -> Cart? {
        Self.snapshot(from: await store.loadAll())
    }

    func cartOutletId() async -> String? {
        await store.loadAll().first?.outletId
    }

    static func snapshot(from entities: [CartItemEntity]) -> Cart? {
        guard let first = entities.first else { return nil }
        let items = entities.map { $0.toCartItem() }
        return CartMath.snapshot(outletId: first.outletId, outletName: first.outletName, items: items)
    }

    // MARK: - Mutations

    @discardableResult
    func addItem(
        foodItem: FoodItem,
        outletName: String,
        quantity: Int,
        customizations: [SelectedCustomization],
        specialInstructions: String?
    ) async throws -> Cart {
        guard foodItem.isAvailable else { throw CartError.unavailable }
        guard quantity >= 1 else { throw CartError.invalidQuantity }
        let qty = min(quantity, CartMath.maxQuantity)

        let existing = await store.loadAll()
        if let current = existing.first, current.outletId != foodItem.outletId {
            throw CartError.outletConflict(currentOutletName: current.outletName)
        }

        let key = CartMath.customizationKey(customizations)
        if let match = existing.first(where: { $0.foodItemId == foodItem.id && $0.customizationKey == key }) {
            match.quantity = min(match.quantity + qty, CartMath.maxQuantity)
            try await store.upsert(match)
        } else {
            let entity = CartItemEntity(
                foodItemId: foodItem.id,
                foodName: foodItem.name,
                foodImageUrl: foodItem.imageUrl,
                outletId: foodItem.outletId,
                outletName: outletName,
                price: foodItem.price,
                quantity: qty,
                isVeg: foodItem.isVeg,
                specialInstructions: specialInstructions,
                customizations: customizations
            )
            try await store.upsert(entity)
        }
        await store.notifyChanged()

        // Best-effort sync; checkout re-syncs authoritatively.
        do { try await pushToBackend() } catch {
            print("⚠️ [Cart] background sync failed: \(describeDecodingError(error))")
        }
        return await currentCart() ?? { let t = CartMath.totals(for: []); return Cart(outletId: foodItem.outletId, outletName: outletName, items: [], subtotal: t.subtotal, tax: t.tax, total: t.total, estimatedPrepMinutes: 0) }()
    }

    @discardableResult
    func updateQuantity(cartItemId: String, quantity: Int) async throws -> Cart {
        let items = await store.loadAll()
        guard let match = items.first(where: { $0.id == cartItemId }) else { throw CartError.emptyCart }
        if quantity <= 0 {
            try await store.delete(id: cartItemId)
        } else {
            match.quantity = min(quantity, CartMath.maxQuantity)
            try await store.upsert(match)
        }
        await store.notifyChanged()
        do { try await pushToBackend() } catch {
            print("⚠️ [Cart] background sync failed: \(describeDecodingError(error))")
        }
        guard let cart = await currentCart() else { throw CartError.emptyCart }
        return cart
    }

    @discardableResult
    func removeItem(cartItemId: String) async throws -> Cart {
        try await store.delete(id: cartItemId)
        await store.notifyChanged()
        do { try await pushToBackend() } catch {
            print("⚠️ [Cart] background sync failed: \(describeDecodingError(error))")
        }
        guard let cart = await currentCart() else { throw CartError.emptyCart }
        return cart
    }

    func clearCart() async throws {
        try await store.clear()
        await store.notifyChanged()
        // Best-effort backend delete (mirrors Android: failures swallowed).
        if let uid = userId {
            do {
                try await client.from("carts").delete().eq("user_id", value: uid).execute()
            } catch {
                print("⚠️ [Cart] backend clear failed: \(describeDecodingError(error))")
            }
        }
    }

    // MARK: - Backend sync

    /// Pull backend cart → local (call after login). Remote wins on outlet
    /// conflict; local-only lines merge when outlets match.
    func syncFromBackend() async throws {
        guard let uid = userId else { return }

        let remote: [RemoteCartRow] = (try? await client.from("carts")
            .select()
            .eq("user_id", value: uid)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value) ?? []
        guard let cartRow = remote.first else { return } // keep local; pushed later

        let itemRows: [RemoteCartItemJoin] = (try? await client.from("cart_items")
            .select("id, food_item_id, quantity, price, is_veg, special_instructions, food_items(name, image_url, outlets(name))")
            .eq("cart_id", value: cartRow.id)
            .execute()
            .value) ?? []

        var customsByItem: [String: [RemoteCustomizationRow]] = [:]
        let ids = itemRows.map { $0.id }
        if !ids.isEmpty {
            let rows: [RemoteCustomizationRow] = (try? await client.from("cart_item_customizations")
                .select()
                .in("cart_item_id", values: ids)
                .execute()
                .value) ?? []
            for r in rows { customsByItem[r.cartItemId, default: []].append(r) }
        }

        // Resolve variant/option display names in one query.
        var variantNames: [String: String] = [:] // "variantId/optionId" -> "Variant: Option"
        var optionExtras: [String: Double] = [:]
        let foodIds = Array(Set(itemRows.map { $0.foodItemId })).filter { !$0.isEmpty }
        if !foodIds.isEmpty {
            let variants: [VariantNameRow] = (try? await client.from("food_variants")
                .select("id, food_item_id, name, food_variant_options(id, name, extra_price)")
                .in("food_item_id", values: foodIds)
                .execute()
                .value) ?? []
            for v in variants {
                for o in v.options ?? [] {
                    variantNames["\(v.id)/\(o.id)"] = "\(v.name): \(o.name)"
                    optionExtras[o.id] = o.extraPrice
                }
            }
        }

        let outletId = cartRow.outletId ?? ""
        var entities: [CartItemEntity] = []
        for item in itemRows {
            let customs = (customsByItem[item.id] ?? []).map { rc -> SelectedCustomization in
                let label = variantNames["\(rc.variantId)/\(rc.optionId)"] ?? ""
                let parts = label.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                return SelectedCustomization(
                    customizationId: rc.variantId,
                    customizationName: parts.first ?? "",
                    optionId: rc.optionId,
                    optionName: parts.count > 1 ? parts[1] : label,
                    extraPrice: optionExtras[rc.optionId] ?? rc.extraPrice
                )
            }
            entities.append(CartItemEntity(
                id: item.id,
                foodItemId: item.foodItemId,
                foodName: item.foodName,
                foodImageUrl: item.foodImageUrl,
                outletId: outletId,
                outletName: item.outletName,
                price: item.price,
                quantity: max(item.quantity, 1),
                isVeg: item.isVeg,
                specialInstructions: item.specialInstructions,
                customizations: customs
            ))
        }

        // Merge local-only lines when outlets match; remote wins otherwise.
        let local = await store.loadAll()
        let remoteKeys = Set(entities.map { "\($0.foodItemId)|\($0.customizationKey)" })
        if let localOutlet = local.first?.outletId, localOutlet == outletId || outletId.isEmpty {
            for l in local where !remoteKeys.contains("\(l.foodItemId)|\(l.customizationKey)") {
                entities.append(l)
            }
        }

        try await store.clear()
        for e in entities { try await store.upsert(e) }
        await store.notifyChanged()
    }

    /// Push local cart → backend. Throws on failure (checkout calls this
    /// authoritatively before `place_order`).
    func pushToBackend() async throws {
        guard let uid = userId else { return } // offline/anonymous: local only
        let entities = await store.loadAll()

        let existing: [RemoteCartRow] = (try? await client.from("carts")
            .select()
            .eq("user_id", value: uid)
            .order("updated_at", ascending: false)
            .execute()
            .value) ?? []

        guard !entities.isEmpty else {
            if !existing.isEmpty {
                try await client.from("carts").delete().eq("user_id", value: uid).execute()
            }
            return
        }

        let outletId = entities.first!.outletId
        let items = entities.map { $0.toCartItem() }
        let t = CartMath.totals(for: items)

        // Local wins on outlet change: drop all remote carts first.
        if existing.first(where: { $0.outletId != nil && $0.outletId != outletId }) != nil {
            try await client.from("carts").delete().eq("user_id", value: uid).execute()
        }

        let cartId: String
        if let same = (try? await client.from("carts").select().eq("user_id", value: uid).limit(1).execute().value as [RemoteCartRow])?.first {
            cartId = same.id
            try await client.from("carts")
                .update(RemoteCartTotalsUpdate(outletId: outletId, subtotal: t.subtotal, tax: t.tax, total: t.total))
                .eq("id", value: cartId)
                .execute()
        } else {
            cartId = UUID().uuidString
            try await client.from("carts")
                .insert(RemoteCartInsert(id: cartId, userId: uid, outletId: outletId, subtotal: t.subtotal, tax: t.tax, total: t.total))
                .execute()
        }

        // Replace lines wholesale (customizations cascade on delete).
        try await client.from("cart_items").delete().eq("cart_id", value: cartId).execute()

        let itemInserts = entities.map { e in
            RemoteCartItemInsert(
                id: e.id, cartId: cartId, foodItemId: e.foodItemId,
                quantity: e.quantity, price: e.price, isVeg: e.isVeg,
                specialInstructions: e.specialInstructions
            )
        }
        try await client.from("cart_items").insert(itemInserts).execute()

        let customInserts = entities.flatMap { e in
            e.customizations.map { c in
                RemoteCustomizationInsert(cartItemId: e.id, variantId: c.customizationId, optionId: c.optionId, extraPrice: c.extraPrice)
            }
        }
        if !customInserts.isEmpty {
            try await client.from("cart_item_customizations").insert(customInserts).execute()
        }
    }
}
