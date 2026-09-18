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
    private let sheet: any PaymentSheetProvider
    private let userEmail: String?
    /// Order placed but payment not yet verified (retry cancels it first,
    /// mirroring Android's stale-order cancellation).
    private var pendingOrderId: String?
    /// Sheet succeeded but server verification has not (yet). Retained so a
    /// verify-timeout/network-loss can be retried as a re-verify of the SAME
    /// order — cancelling here could cancel an order the server already
    /// captured payment for.
    private var pendingVerification: (order: Order, request: PaymentVerificationRequest)?

    init(cart: Cart, repository: AppRepository, userEmail: String? = nil, sheet: (any PaymentSheetProvider)? = nil) {
        self.cart = cart
        self.repository = repository
        self.userEmail = userEmail
        self.sheet = sheet ?? RazorpayService.shared
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

    /// Sheet waits have no intrinsic timeout: if the native sheet is killed
    /// or its delegate never fires, abandon the wait so the user isn't stuck.
    /// Razorpay UPI/bank flows can legitimately take minutes, hence 300s.
    private static let sheetTimeout: Duration = .seconds(300)
    private var sheetTimeoutTask: Task<Void, Never>?

    func placeOrder() async {
        guard let slot = selectedSlot, !cart.isEmpty else { return }
        // Retry is only allowed from terminal failure states.
        switch flowState {
        case .idle, .error, .paymentCancelled: break
        default: return
        }
        // A verify-stage failure must re-verify the SAME order — even via the
        // main button. Cancelling here could cancel captured payment.
        if case .error = flowState, pendingVerification != nil {
            await retryVerification()
            return
        }
        flowState = .placing

        do {
            // Cancel a stale order from a previous failed attempt first.
            // Best-effort by design: if the cancel fails, the stale order
            // lingers server-side but the new placement still proceeds (the
            // returned order is intentionally discarded).
            if let stale = pendingOrderId {
                _ = try? await repository.orders.cancelOrder(orderId: stale, reason: "Payment retried or cancelled by user")
                pendingOrderId = nil
            }

            // Authoritative backend sync before placing (never blind-submit).
            try await repository.cart.pushToBackend()

            let order = try await repository.orders.placeOrder(
                pickupSlotId: slot.id,
                paymentMethod: paymentMethod
            )
            pendingOrderId = order.id
            pendingVerification = nil // fresh order, previous verify context is stale

            if paymentMethod == .payAtCounter {
                try? await repository.cart.clearCart()
                pendingOrderId = nil
                flowState = .success(order: order)
                return
            }

            // ONLINE: create Razorpay order, open sheet, verify server-side.
            flowState = .awaitingPayment(order: order)
            let details = try await repository.payments.createRazorpayOrder(orderId: order.id)

            armSheetTimeout(for: order.id)
            let sheetResult = await sheet.pay(
                keyId: details.keyId,
                amountPaise: details.amount,
                razorpayOrderId: details.razorpayOrderId,
                outletName: cart.outletName,
                email: userEmail
            )
            disarmSheetTimeout()

            switch sheetResult {
            case .success(let paymentId, let rzOrderId, let signature):
                let request = PaymentVerificationRequest(
                    orderId: order.id,
                    razorpayOrderId: rzOrderId,
                    razorpayPaymentId: paymentId,
                    razorpaySignature: signature
                )
                pendingVerification = (order, request)
                flowState = .verifying(order: order)
                try await verifyPayment(order: order, request: request)

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

    /// User escape hatch while waiting on the sheet: abandon the wait and
    /// keep the order + cart intact for a later retry.
    func cancelAwaitingPayment() {
        guard case .awaitingPayment(let order) = flowState else { return }
        disarmSheetTimeout()
        sheet.abandon()
        flowState = .paymentCancelled(orderId: order.id)
    }

    private func armSheetTimeout(for orderId: String) {
        disarmSheetTimeout()
        sheetTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.sheetTimeout)
            guard let self, !Task.isCancelled else { return }
            // Only fire if still waiting on the same order; a completed sheet
            // disarms first, and a late delegate resolves to `.cancelled`.
            guard case .awaitingPayment(let waiting) = self.flowState,
                  waiting.id == orderId else { return }
            self.sheet.abandon()
            self.flowState = .paymentCancelled(orderId: orderId)
        }
    }

    private func disarmSheetTimeout() {
        sheetTimeoutTask?.cancel()
        sheetTimeoutTask = nil
    }

    /// Server-side verification + post-payment cleanup. Throws on failure so
    /// the caller lands in `.error` WITH `pendingVerification` retained for
    /// an idempotent re-verify retry.
    private func verifyPayment(order: Order, request: PaymentVerificationRequest) async throws {
        try await repository.payments.verifyRazorpayPayment(request)
        try? await repository.cart.clearCart()
        pendingOrderId = nil
        pendingVerification = nil
        flowState = .success(order: order)
    }

    /// Re-verify the same order after a verify-stage failure (timeout,
    /// network loss, backend error). Never cancels: the server may already
    /// have captured payment.
    func retryVerification() async {
        guard case .error = flowState, let pending = pendingVerification else { return }
        flowState = .verifying(order: pending.order)
        do {
            try await verifyPayment(order: pending.order, request: pending.request)
        } catch is CancellationError {
            flowState = .idle
        } catch {
            flowState = .error(message: error.localizedDescription)
        }
    }

    func retryAfterError() async {
        // A verify-stage failure retries verification of the same order;
        // anything earlier re-places (cancelling the stale order first).
        if case .error = flowState, pendingVerification != nil {
            await retryVerification()
            return
        }
        if case .error = flowState { flowState = .idle }
        if case .paymentCancelled = flowState { flowState = .idle }
        await placeOrder()
    }
}
