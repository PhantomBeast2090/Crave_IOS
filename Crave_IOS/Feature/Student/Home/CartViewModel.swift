import Foundation
import Observation

@MainActor
@Observable
final class CartViewModel {
    private(set) var cart: Cart?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Loaded pickup slots per outlet (today). Used for display + matching.
    private(set) var slotsByOutlet: [String: [PickupSlot]] = [:]
    private(set) var slotsLoading = false

    /// Match-slots selection mode (temporary; rows stay clean otherwise).
    var matchMode = false
    var selectedItemIds = Set<String>()
    private(set) var matchWindows: [SlotMatcher.CommonWindow] = []
    private(set) var matchError: String?
    private(set) var isMatching = false

    private let repository: CartRepository
    private let orders: OrderRepository
    private var observeTask: Task<Void, Never>?

    init(cart: CartRepository, orders: OrderRepository) {
        self.repository = cart
        self.orders = orders
    }

    var isEmpty: Bool { cart?.isEmpty ?? true }
    var itemCount: Int { cart?.totalItems ?? 0 }
    var subtotal: Double { cart?.subtotal ?? 0 }
    var tax: Double { cart?.tax ?? 0 }
    var total: Double { cart?.total ?? 0 }

    func start() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.repository.observeCart() {
                self.cart = updated
            }
        }
        Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }
            await self.sync()
        }
        Task { [weak self] in await self?.loadSlots() }
    }

    /// Pull-to-refresh entry point (also used by `start`). Sync failures are
    /// silent when local items exist (offline-friendly); when the cart ends
    /// up empty the error is shown so the user isn't left guessing.
    func sync() async {
        do {
            try await repository.syncFromBackend()
        } catch is CancellationError {
            // Ignore — view went away.
        } catch {
            print("⚠️ [CartViewModel] backend sync failed: \(error)")
            if isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
    }

    // MARK: - Mutations

    func requestAdd(
        foodItem: FoodItem,
        outletName: String,
        quantity: Int = 1,
        customizations: [SelectedCustomization] = [],
        specialInstructions: String? = nil
    ) async -> Bool {
        errorMessage = nil
        do {
            _ = try await repository.addItem(
                foodItem: foodItem,
                outletName: outletName,
                quantity: quantity,
                customizations: customizations,
                specialInstructions: specialInstructions
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateQuantity(_ item: CartItem, quantity: Int) async {
        errorMessage = nil
        do {
            _ = try await repository.updateQuantity(cartItemId: item.id, quantity: quantity)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeItem(_ item: CartItem) async {
        errorMessage = nil
        do {
            _ = try await repository.removeItem(cartItemId: item.id)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCart() async {
        errorMessage = nil
        do {
            try await repository.clearCart()
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Slots

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Load today's slots for every outlet in the cart (best-effort per
    /// outlet; one outlet failing never blocks the others).
    func loadSlots() async {
        guard let cart, !cart.isEmpty else { return }
        slotsLoading = true
        defer { slotsLoading = false }
        let today = Self.todayString()
        let orders = self.orders
        let outletIds = cart.outletIds
        await withTaskGroup(of: (String, [PickupSlot]).self) { group in
            for outletId in outletIds {
                group.addTask {
                    do {
                        let slots = try await orders.getPickupSlots(outletId: outletId, date: today)
                        return (outletId, slots)
                    } catch {
                        return (outletId, [])
                    }
                }
            }
            for await (outletId, slots) in group {
                slotsByOutlet[outletId] = slots
            }
        }
    }

    /// Resolve a line's chosen slot for display (nil when not chosen or the
    /// slot list hasn't loaded / no longer contains it).
    func slot(for item: CartItem) -> PickupSlot? {
        guard let slotId = item.slotId else { return nil }
        return slotsByOutlet[item.outletId]?.first(where: { $0.id == slotId })
    }

    func setItemSlot(_ item: CartItem, slotId: String?) async {
        errorMessage = nil
        do {
            _ = try await repository.setSlot(cartItemId: item.id, slotId: slotId)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Match selected slots

    func enterMatchMode() {
        selectedItemIds = []
        matchWindows = []
        matchError = nil
        matchMode = true
    }

    func exitMatchMode() {
        matchMode = false
        selectedItemIds = []
        matchWindows = []
        matchError = nil
    }

    func toggleSelect(_ item: CartItem) {
        if selectedItemIds.contains(item.id) {
            selectedItemIds.remove(item.id)
        } else {
            selectedItemIds.insert(item.id)
        }
        matchWindows = []
        matchError = nil
    }

    /// Compute common windows across the selected items' outlets.
    func computeMatches() async {
        guard let cart else { return }
        let selected = cart.items.filter { selectedItemIds.contains($0.id) }
        guard selected.count >= 2 else {
            matchError = "Select at least two items to match."
            return
        }
        isMatching = true
        defer { isMatching = false }
        await loadSlots()
        var byOutlet: [String: [PickupSlot]] = [:]
        for item in selected {
            byOutlet[item.outletId] = slotsByOutlet[item.outletId] ?? []
        }
        let windows = SlotMatcher.commonWindows(slotsByOutlet: byOutlet)
        if windows.isEmpty {
            matchError = "These items don't share a common pickup slot. Keep per-outlet slots or remove an item."
        }
        matchWindows = windows
    }

    /// Apply a common window: each selected item gets its outlet's slot in
    /// that window. Outlets without the window keep their current slot.
    func applyMatch(_ window: SlotMatcher.CommonWindow) async {
        guard let cart else { return }
        let ids = SlotMatcher.slotIds(for: window, in: slotsByOutlet)
        errorMessage = nil
        do {
            for item in cart.items where selectedItemIds.contains(item.id) {
                guard let slotId = ids[item.outletId] else { continue }
                _ = try await repository.setSlot(cartItemId: item.id, slotId: slotId)
            }
            exitMatchMode()
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
