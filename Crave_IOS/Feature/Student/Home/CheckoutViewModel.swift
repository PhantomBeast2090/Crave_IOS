import Foundation
import Observation

/// Checkout state machine (mirrors Android CheckoutViewModel + CheckoutScreen
/// flow), including the ONLINE Razorpay lifecycle:
///
/// place_order → create-razorpay-order → sheet → verify-razorpay-payment →
/// success. The cart is cleared only after PAY_AT_COUNTER placement or
/// verified ONLINE payment — never before.
@MainActor
@Observable
final class CheckoutViewModel {
    enum SlotsState: Equatable {
        case idle
        case loading
        case loaded([PickupSlot])
        case empty
        case error(message: String)

        static func == (lhs: SlotsState, rhs: SlotsState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.empty, .empty): return true
            case (.loaded(let a), .loaded(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    enum FlowState: Equatable {
        case idle
        case placing
        case awaitingPayment(order: Order)
        case verifying(order: Order)
        case success(order: Order)
        case paymentCancelled(orderId: String)
        case error(message: String)

        static func == (lhs: FlowState, rhs: FlowState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.placing, .placing): return true
            case (.awaitingPayment(let a), .awaitingPayment(let b)): return a.id == b.id
            case (.verifying(let a), .verifying(let b)): return a.id == b.id
            case (.success(let a), .success(let b)): return a.id == b.id
            case (.paymentCancelled(let a), .paymentCancelled(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    private(set) var slotsState: SlotsState = .idle
    private(set) var flowState: FlowState = .idle
    var selectedSlot: PickupSlot?
    /// Android defaults to ONLINE; PAY_AT_COUNTER is also supported by the backend.
    var paymentMethod: PaymentMethod = .online

    let cart: Cart
    private let repository: AppRepository
    private let userEmail: String?
    /// Order placed but payment not yet verified (retry cancels it first,
    /// mirroring Android's stale-order cancellation).
    private var pendingOrderId: String?

    init(cart: Cart, repository: AppRepository, userEmail: String? = nil) {
        self.cart = cart
        self.repository = repository
        self.userEmail = userEmail
    }

    var canPlaceOrder: Bool {
        guard selectedSlot != nil, !cart.isEmpty else { return false }
        switch flowState {
        case .placing, .verifying, .awaitingPayment: return false
        default: return true
        }
    }

    // MARK: - Slots (today only, like Android)

    func loadSlots() async {
        guard case .idle = slotsState else { return }
        slotsState = .loading
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        do {
            let slots = try await repository.orders.getPickupSlots(outletId: cart.outletId, date: today)
            slotsState = slots.isEmpty ? .empty : .loaded(slots)
        } catch is CancellationError {
            slotsState = .idle
        } catch {
            slotsState = .error(message: error.localizedDescription)
        }
    }

    func retrySlots() async {
        slotsState = .idle
        await loadSlots()
    }

    // MARK: - Placement

    func placeOrder() async {
        guard let slot = selectedSlot, !cart.isEmpty else { return }
        // Retry is only allowed from terminal failure states.
        switch flowState {
        case .idle, .error, .paymentCancelled: break
        default: return
        }
        flowState = .placing

        do {
            // Cancel a stale order from a previous failed attempt first.
            if let stale = pendingOrderId {
                try? await repository.orders.cancelOrder(orderId: stale, reason: "Payment retried or cancelled by user")
                pendingOrderId = nil
            }

            // Authoritative backend sync before placing (never blind-submit).
            try await repository.cart.pushToBackend()

            let order = try await repository.orders.placeOrder(
                pickupSlotId: slot.id,
                paymentMethod: paymentMethod
            )
            pendingOrderId = order.id

            if paymentMethod == .payAtCounter {
                try? await repository.cart.clearCart()
                pendingOrderId = nil
                flowState = .success(order: order)
                return
            }

            // ONLINE: create Razorpay order, open sheet, verify server-side.
            flowState = .awaitingPayment(order: order)
            let details = try await repository.payments.createRazorpayOrder(orderId: order.id)

            let sheetResult = await RazorpayService.shared.pay(
                keyId: details.keyId,
                amountPaise: details.amount,
                razorpayOrderId: details.razorpayOrderId,
                outletName: cart.outletName,
                email: userEmail
            )

            switch sheetResult {
            case .success(let paymentId, let rzOrderId, let signature):
                flowState = .verifying(order: order)
                try await repository.payments.verifyRazorpayPayment(PaymentVerificationRequest(
                    orderId: order.id,
                    razorpayOrderId: rzOrderId,
                    razorpayPaymentId: paymentId,
                    razorpaySignature: signature
                ))
                try? await repository.cart.clearCart()
                pendingOrderId = nil
                flowState = .success(order: order)

            case .cancelled:
                // Order remains, cart intact — user can retry or pay later.
                flowState = .paymentCancelled(orderId: order.id)

            case .failed(let message):
                flowState = .error(message: message)
            }
        } catch is CancellationError {
            flowState = .idle
        } catch {
            flowState = .error(message: error.localizedDescription)
        }
    }

    func retryAfterError() async {
        if case .error = flowState { flowState = .idle }
        if case .paymentCancelled = flowState { flowState = .idle }
        await placeOrder()
    }
}
