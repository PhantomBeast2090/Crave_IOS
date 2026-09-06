import Foundation
import Supabase

/// Razorpay edge-function calls. The public `key_id` is returned per-order by
/// the backend — no keys are stored in the app.
struct SupabasePaymentRepository: PaymentRepository, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    var isOnlinePaymentConfigured: Bool { true }

    func createRazorpayOrder(orderId: String) async throws -> RazorpayOrderDetails {
        do {
            let details: RazorpayOrderDetails = try await client.functions.invoke(
                "create-razorpay-order",
                options: FunctionInvokeOptions(body: CreateRazorpayOrderRequest(orderId: orderId))
            )
            guard !details.keyId.isEmpty, !details.razorpayOrderId.isEmpty else {
                throw AppError.message("Online payment is not configured for this outlet yet.")
            }
            return details
        } catch let appError as AppError {
            throw appError
        } catch {
            print("❌ [Payment] create-razorpay-order failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Couldn't start online payment. Please try again.")
        }
    }

    func verifyRazorpayPayment(_ request: PaymentVerificationRequest) async throws {
        struct VerifyResponse: Decodable, Sendable {
            let success: Bool
            let message: String?
            init(from decoder: any Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? false
                message = try? c.decodeIfPresent(String.self, forKey: .message)
            }
            enum CodingKeys: String, CodingKey { case success, message }
        }
        do {
            let response: VerifyResponse = try await client.functions.invoke(
                "verify-razorpay-payment",
                options: FunctionInvokeOptions(body: request)
            )
            guard response.success else {
                throw AppError.message(response.message ?? "Payment verification failed.")
            }
        } catch let appError as AppError {
            throw appError
        } catch {
            print("❌ [Payment] verify-razorpay-payment failed: \(describeDecodingError(error))")
            throw AppError.message(parsePostgrestMessage(error) ?? "Payment verification failed. Your money is safe — contact support with your order ID.")
        }
    }
}
