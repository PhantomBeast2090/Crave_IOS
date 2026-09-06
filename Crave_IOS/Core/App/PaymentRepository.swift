import Foundation

// MARK: - Payment Repository Protocol (mirrors Android PaymentRepository)

protocol PaymentRepository: Sendable {
    /// Invoke `create-razorpay-order` for a backend order id.
    func createRazorpayOrder(orderId: String) async throws -> RazorpayOrderDetails

    /// Invoke `verify-razorpay-payment` after the Razorpay sheet succeeds.
    /// Server verification is authoritative — never trust the sheet alone.
    func verifyRazorpayPayment(_ request: PaymentVerificationRequest) async throws

    /// Razorpay public key id. Nil when the backend hasn't been configured
    /// with one — the UI must then hide/disable ONLINE payment explicitly
    /// instead of fabricating credentials.
    var isOnlinePaymentConfigured: Bool { get }
}

// MARK: - Razorpay sheet result ( maps the native SDK callback )

nonisolated enum RazorpaySheetResult: Sendable, Equatable {
    case success(paymentId: String, orderId: String, signature: String)
    case cancelled
    case failed(message: String)
}
