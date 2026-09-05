import SwiftUI

/// Search tab — wired to the `search_food` RPC in the backend stage.
struct SearchView: View {
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: GagShapes.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(GagColors.onSurfaceVariant)
                TextField("Search food, outlets…", text: $query)
                    .font(GagTypography.bodyLarge)
                    .foregroundStyle(GagColors.onSurface)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(GagColors.onSurfaceDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, GagShapes.spacingL)
            .frame(height: 48)
            .background(GagColors.surfaceVariant)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
            .padding(GagShapes.spacingL)

            Spacer()

            GagEmptyView(
                icon: "magnifyingglass",
                title: "Search food & outlets",
                message: "Start typing to find dishes, customizations, and outlets across campus."
            )
            .padding(.bottom, GagShapes.spacingXXL)

            Spacer()
        }
        .background(GagColors.background)
        .navigationTitle("Search")
    }
}

#Preview {
    NavigationStack { SearchView() }
}
