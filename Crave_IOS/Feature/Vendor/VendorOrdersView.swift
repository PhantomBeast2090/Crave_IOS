import SwiftUI

/// Vendor order queue scaffold — realtime order list in the vendor stage.
struct VendorOrdersView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GagEmptyView(
                    icon: "shippingbox",
                    title: "No orders",
                    message: "Incoming orders will show up here."
                )
                .padding(.top, 120)
            }
        }
        .background(GagColors.background)
        .navigationTitle("Orders")
    }
}

#Preview {
    NavigationStack { VendorOrdersView() }
}
