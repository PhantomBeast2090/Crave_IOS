import SwiftUI
import UIKit

/// Help & support — FAQ + contact (mirrors Android HelpScreen).
struct HelpView: View {
    private static let faqs: [(question: String, answer: String)] = [
        ("How do I place an order?",
         "Browse the menu, add items to your cart, select a pickup slot, and complete the payment through Razorpay or Pay at Counter."),
        ("How do pickup slots work?",
         "To manage demand, you must select a specific time slot to pick up your food. Slots have limited capacity. Please arrive during your selected time window."),
        ("How do I cancel an order?",
         "You can cancel an order from its details screen while it hasn't been prepared yet. Contact the outlet directly for urgent cancellations."),
        ("How does online payment work?",
         "We use Razorpay to securely process online payments. If a payment fails, your cart is preserved and you can try again."),
        ("My payment succeeded but the order failed?",
         "This is rare, but if it happens, your payment will automatically be refunded by Razorpay within 5-7 business days."),
    ]

    @State private var expandedIndex: Int?

    var body: some View {
        List {
            Section("Contact Us") {
                Button {
                    emailSupport()
                } label: {
                    Label("Email Support", systemImage: "envelope")
                        .foregroundStyle(GagColors.onSurface)
                }
            }

            Section("Frequently Asked Questions") {
                ForEach(Array(Self.faqs.enumerated()), id: \.offset) { index, faq in
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation {
                                expandedIndex = expandedIndex == index ? nil : index
                            }
                        } label: {
                            HStack {
                                Text(faq.question)
                                    .font(GagTypography.labelLarge)
                                    .foregroundStyle(GagColors.onSurface)
                                Spacer()
                                Image(systemName: expandedIndex == index ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(GagColors.onSurfaceVariant)
                            }
                        }
                        .buttonStyle(.plain)
                        if expandedIndex == index {
                            Text(faq.answer)
                                .font(GagTypography.bodySmall)
                                .foregroundStyle(GagColors.onSurfaceVariant)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Legal & About") {
                Label("About Crave — Version 1.0.0", systemImage: "info.circle")
                    .foregroundStyle(GagColors.onSurface)
            }
        }
        .background(GagColors.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func emailSupport() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@srmfood.com"
        components.queryItems = [URLQueryItem(name: "subject", value: "Crave App Support Request")]
        if let url = components.url {
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        }
    }
}

#Preview {
    NavigationStack { HelpView() }
}
