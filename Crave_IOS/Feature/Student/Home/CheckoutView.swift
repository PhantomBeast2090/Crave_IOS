import SwiftUI
import SwiftData

struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(CartViewModel.self) private var cartViewModel
    
    @State private var selectedSlot: PickupSlot?
    @State private var specialInstructions = ""
    @State private var isPlacingOrder = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                    // Pickup slot selection
                    VStack(alignment: .leading, spacing: GagShapes.spacingM) {
                        Text("Pickup Time")
                            .font(GagTypography.titleMedium)
                            .foregroundStyle(GagColors.onSurface)
                        
                        // Mock slots - replace with real API
                        VStack(spacing: GagShapes.spacingS) {
                            ForEach(mockSlots) { slot in
                                PickupSlotRow(
                                    slot: slot,
                                    isSelected: selectedSlot?.id == slot.id,
                                    action: { selectedSlot = slot }
                                )
                            }
                        }
                    }
                    
                    // Special instructions
                    VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                        Text("Special Instructions (optional)")
                            .font(GagTypography.labelLarge)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                        
                        TextField("e.g., Extra spicy, no onions", text: $specialInstructions, axis: .vertical)
                            .font(GagTypography.bodyMedium)
                            .padding(GagShapes.spacingM)
                            .background(GagColors.surfaceVariant)
                            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                            .lineLimit(3...5)
                    }
                    
                    // Order summary
                    VStack(spacing: GagShapes.spacingS) {
                        SummaryRow(label: "Subtotal", value: cartViewModel.subtotal)
                        SummaryRow(label: "Tax (5%)", value: cartViewModel.tax)
                        Divider()
                        SummaryRow(label: "Total", value: cartViewModel.total, isTotal: true)
                    }
                    .gagCard()
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(GagTypography.labelMedium)
                            .foregroundStyle(GagColors.error)
                    }
                    
                    GagButton(
                        title: "Place Order",
                        isLoading: isPlacingOrder,
                        isEnabled: selectedSlot != nil && !cartViewModel.isEmpty,
                        action: placeOrder
                    )
                }
                .padding(GagShapes.spacingL)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Order Placed!", isPresented: $showSuccess) {
                Button("Track Order") {
                    dismiss()
                    // Navigate to orders tab
                }
                Button("Continue Shopping", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Your order has been placed successfully. You'll receive a notification when it's ready for pickup.")
            }
        }
    }
    
    private var mockSlots: [PickupSlot] {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return [
            PickupSlot(id: "1", outletId: "", startTime: formatter.string(from: now.addingTimeInterval(1800)), endTime: formatter.string(from: now.addingTimeInterval(2100)), date: "Today", capacity: 20, bookedCount: 5, status: .available),
            PickupSlot(id: "2", outletId: "", startTime: formatter.string(from: now.addingTimeInterval(3600)), endTime: formatter.string(from: now.addingTimeInterval(3900)), date: "Today", capacity: 20, bookedCount: 12, status: .limited),
            PickupSlot(id: "3", outletId: "", startTime: formatter.string(from: now.addingTimeInterval(5400)), endTime: formatter.string(from: now.addingTimeInterval(5700)), date: "Today", capacity: 20, bookedCount: 18, status: .limited),
        ]
    }
    
    private func placeOrder() {
        guard let slot = selectedSlot else { return }
        isPlacingOrder = true
        errorMessage = nil
        
        // TODO: Call real place_order RPC
        // For now, simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPlacingOrder = false
            // Create order entity
            let order = OrderEntity(
                orderNumber: "GAG-\(Int.random(in: 100000...999999))",
                items: cartViewModel.items.map { item in
                    OrderItemEntity(
                        foodItemId: item.foodItemId,
                        foodName: item.foodName,
                        foodImageUrl: item.foodImageUrl,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        customizations: item.customizationNames,
                        isVeg: item.isVeg
                    )
                },
                subtotal: cartViewModel.subtotal,
                tax: cartViewModel.tax,
                total: cartViewModel.total,
                status: .placed,
                pickupSlot: slot,
                estimatedPrepMinutes: 15,
                paymentStatus: .pending,
                paymentMethod: .payAtCounter,
                specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions
            )
            modelContext.insert(order)
            cartViewModel.clearCart()
            showSuccess = true
        }
    }
}

struct PickupSlotRow: View {
    let slot: PickupSlot
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.displayTime)
                        .font(GagTypography.labelLarge)
                        .foregroundStyle(GagColors.onSurface)
                    Text("\(slot.availableCount) slots left")
                        .font(GagTypography.labelSmall)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? GagColors.brandOrange : GagColors.outlineVariant)
            }
            .padding(GagShapes.spacingM)
            .background(GagColors.surface)
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
            .overlay(
                GagShapes.cornerRadius(GagShapes.radiusLarge)
                    .stroke(isSelected ? GagColors.brandOrange : GagColors.outlineVariant, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(slot.status == .full)
        .opacity(slot.status == .full ? 0.5 : 1)
    }
}
