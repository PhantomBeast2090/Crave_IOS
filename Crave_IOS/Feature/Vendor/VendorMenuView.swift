import SwiftUI

/// Vendor menu management scaffold — food CRUD in the vendor stage.
struct VendorMenuView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GagEmptyView(
                    icon: "menucard",
                    title: "Your menu is empty",
                    message: "Add and manage food items for your outlet here."
                )
                .padding(.top, 120)
            }
        }
        .background(GagColors.background)
        .navigationTitle("Menu")
    }
}

#Preview {
    NavigationStack { VendorMenuView() }
}
