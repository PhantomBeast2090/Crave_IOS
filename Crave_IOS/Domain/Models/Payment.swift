import Foundation

/// Razorpay order details returned by the `create-razorpay-order` edge function.
nonisolated struct RazorpayOrderDetails: Sendable, Codable, Hashable {
    let razorpayOrderId: String
    let amount: Int
    let keyId: String
    let currency: String

    enum CodingKeys: String, CodingKey {
        case razorpayOrderId = "razorpay_order_id"
        case amount
        case keyId = "key_id"
        case currency
    }
}

/// Payload sent to the `verify-razorpay-payment` edge function.
nonisolated struct PaymentVerificationRequest: Sendable, Codable {
    let orderId: String
    let razorpayOrderId: String
    let razorpayPaymentId: String
    let razorpaySignature: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case razorpayOrderId = "razorpay_order_id"
        case razorpayPaymentId = "razorpay_payment_id"
        case razorpaySignature = "razorpay_signature"
    }
}

nonisolated struct PaymentVerificationResponse: Sendable, Codable {
    let success: Bool
    let message: String
}
