import SwiftUI

/// Order history tab — real order list once the order repository is wired.
struct OrderHistoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GagEmptyView(
                    icon: "shippingbox",
                    title: "No orders yet",
                    message: "When you place an order, it will show up here with live tracking."
                )
                .padding(.top, 120)
            }
        }
        .background(GagColors.background)
        .navigationTitle("Orders")
    }
}

#Preview {
    NavigationStack { OrderHistoryView() }
}
