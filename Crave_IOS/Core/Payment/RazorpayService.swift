import Foundation
import RazorpayCheckout

/// Native Razorpay sheet bridge (mirrors Android's RazorpayManager +
/// `com.razorpay.Checkout` flow).
///
/// Flow: backend `create-razorpay-order` → server returns `key_id` (public)
/// and `razorpay_order_id` → sheet opens → result maps to
/// `RazorpaySheetResult`. Server-side `verify-razorpay-payment` remains
/// authoritative; this sheet result alone never marks payment success.
@MainActor
final class RazorpayService: NSObject, PaymentCompletionWithDataDelegate {
    static let shared = RazorpayService()

    private var checkout: RazorpaySwift?
    private var continuation: CheckedContinuation<RazorpaySheetResult, Never>?

    /// Open the Razorpay sheet. Exactly one sheet at a time.
    func pay(
        keyId: String,
        amountPaise: Int,
        razorpayOrderId: String,
        outletName: String,
        email: String?
    ) async -> RazorpaySheetResult {
        // Drop any stale continuation instead of leaking it.
        if let pending = continuation {
            continuation = nil
            pending.resume(returning: .cancelled)
        }
        return await withCheckedContinuation { cont in
            continuation = cont
            var payload: [AnyHashable: Any] = [
                "amount": amountPaise,
                "currency": "INR",
                "description": "Food Pre-order",
                "order_id": razorpayOrderId,
                "name": "Crave",
                "theme": ["color": "#E8431A"],
            ]
            if let email, !email.isEmpty {
                payload["prefill"] = ["email": email]
            }

            let checkout = RazorpaySwift.initWithKey(key: keyId, andDelegateWithData: self)
            self.checkout = checkout
            do {
                try checkout.open(withPayload: payload)
            } catch {
                takeContinuation()?.resume(returning: .failed(message: error.localizedDescription))
            }
        }
    }

    // MARK: - PaymentCompletionWithDataDelegate

    func onPaymentSuccess(_ payment_id: String, andData response: [AnyHashable: Any]?) {
        guard let cont = takeContinuation() else { return }
        let paymentId = (response?["razorpay_payment_id"] as? String) ?? payment_id
        let orderId = (response?["razorpay_order_id"] as? String) ?? ""
        let signature = (response?["razorpay_signature"] as? String) ?? ""
        cont.resume(returning: .success(paymentId: paymentId, orderId: orderId, signature: signature))
    }

    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable: Any]?) {
        guard let cont = takeContinuation() else { return }
        if code == 0 || str.localizedCaseInsensitiveContains("cancel") {
            cont.resume(returning: .cancelled)
        } else {
            cont.resume(returning: .failed(message: str.isEmpty ? "Payment failed (code \(code))." : str))
        }
    }

    private func takeContinuation() -> CheckedContinuation<RazorpaySheetResult, Never>? {
        let cont = continuation
        continuation = nil
        checkout = nil
        return cont
    }
}
