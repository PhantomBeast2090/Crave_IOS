import SwiftUI

/// Green triangle (veg) / red diamond (non-veg) indicator.
struct VegIndicator: View {
    let isVeg: Bool
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(isVeg ? GagColors.vegGreen : GagColors.nonVegRed, lineWidth: 1.5)
                .frame(width: size, height: size)
            Circle()
                .fill(isVeg ? GagColors.vegGreen : GagColors.nonVegRed)
                .frame(width: size * 0.45)
        }
    }
}

/// Food item card used in home feed, search results, outlet detail.
///
/// NOTE: this is a pure view — it must NOT wrap itself in a Button. Parent
/// screens place it inside a NavigationLink, and an inner Button swallows
/// taps so navigation never fires (previous root cause of unreachable food
/// detail). The quick-add control is a separate inner Button and stays
/// tappable inside the link.
struct FoodItemCard: View {
    let item: FoodItem
    var onAddToCart: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: GagShapes.spacingM) {
                foodImage

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        VegIndicator(isVeg: item.isVeg)
                        Text(item.name)
                            .font(GagTypography.titleSmall)
                            .foregroundStyle(GagColors.onSurface)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if item.isPopular {
                            Text("POPULAR")
                                .font(GagTypography.labelSmall)
                                .foregroundStyle(GagColors.brandOrange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(GagColors.brandOrange.opacity(0.12))
                                .clipShape(GagShapes.cornerRadius(GagShapes.radiusSmall))
                        }
                    }

                    Text(item.description)
                        .font(GagTypography.bodySmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(Formatters.price(item.price))
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.onSurface)

                        if item.rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(GagColors.amber)
                                Text(String(format: "%.1f", item.rating))
                                    .font(GagTypography.labelSmall)
                                    .foregroundStyle(GagColors.onSurfaceVariant)
                            }
                        }

                        Text("\(item.prepTimeMinutes) min")
                            .font(GagTypography.labelSmall)
                            .foregroundStyle(GagColors.onSurfaceDim)

                        Spacer(minLength: 0)

                        if let onAddToCart {
                            Button {
                                onAddToCart()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(GagColors.brandOrange)
                                    .clipShape(Circle())
                                    .padding(5)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!item.isAvailable)
                            .opacity(item.isAvailable ? 1 : 0.4)
                        }
                    }
                }
            }
            .padding(GagShapes.spacingM)
            .background(GagColors.surface)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusXLarge))
            .overlay(
                GagShapes.cornerRadius(GagShapes.radiusXLarge)
                    .stroke(GagColors.outlineVariant, lineWidth: 1)
            )
    }

    private var foodImage: some View {
        Group {
            if let urlString = item.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }

    private var placeholder: some View {
        ZStack {
            GagColors.surfaceVariant
            Image(systemName: "fork.knife")
                .font(.system(size: 24))
                .foregroundStyle(GagColors.onSurfaceDim)
        }
    }
}
