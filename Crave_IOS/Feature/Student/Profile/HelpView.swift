import SwiftUI

/// Help & support — FAQ / contact info.
struct HelpView: View {
    var body: some View {
        List {
            Section("FAQs") {
                faqRow("How do I pick up my order?", "When your order is READY, a QR code appears on the order screen. Show it at the outlet counter.")
                faqRow("Can I pay at the counter?", "Yes — select 'Pay at Counter' at checkout.")
                faqRow("What if the outlet rejects my order?", "You'll be notified and any inventory/slot held for you is released automatically.")
            }

            Section("Contact") {
                Label("support@crave.app", systemImage: "envelope")
                Label("+91 98765 43210", systemImage: "phone")
            }
        }
        .background(GagColors.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faqRow(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(q)
                .font(GagTypography.labelLarge)
                .foregroundStyle(GagColors.onSurface)
            Text(a)
                .font(GagTypography.bodySmall)
                .foregroundStyle(GagColors.onSurfaceVariant)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { HelpView() }
}
