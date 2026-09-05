import SwiftUI
import SwiftData

struct OrdersView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: OrdersViewModel?
    @State private var selectedOrder: OrderEntity?
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Loading orders…")
                    .task { viewModel = OrdersViewModel(modelContext: modelContext) }
            }
        }
        .navigationTitle("Orders")
        .sheet(item: $selectedOrder) { order in
            OrderDetailView(order: order)
        }
    }
    
    @ViewBuilder
    private func content(viewModel: OrdersViewModel) -> some View {
        if viewModel.orders.isEmpty {
            GagEmptyView(
                icon: "bag",
                title: "No orders yet",
                message: "Your order history will appear here.",
                actionTitle: "Browse Food",
                action: { }
            )
        } else {
            List {
                ForEach(viewModel.orders) { order in
                    OrderRow(order: order)
                        .onTapGesture { selectedOrder = order }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
        }
    }
}

struct OrderRow: View {
    let order: OrderEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: GagShapes.spacingM) {
            HStack {
                Text(order.orderNumber)
                    .font(GagTypography.titleSmall)
                    .foregroundStyle(GagColors.onSurface)
                Spacer()
                OrderStatusBadge(status: order.status)
            }
            
            HStack(spacing: GagShapes.spacingM) {
                Label(order.pickupSlot?.displayTime ?? "—", systemImage: "clock")
                Label(Formatters.price(order.total), systemImage: "indianrupeesign.circle")
            }
            .font(GagTypography.labelMedium)
            .foregroundStyle(GagColors.onSurfaceVariant)
            
            Text(order.items.map { "\($0.quantity)× \($0.foodName)" }.joined(separator: ", "))
                .font(GagTypography.bodySmall)
                .foregroundStyle(GagColors.onSurfaceDim)
                .lineLimit(1)
        }
        .padding(GagShapes.spacingM)
        .background(GagColors.surface)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusXLarge))
        .overlay(
            GagShapes.cornerRadius(GagShapes.radiusXLarge)
                .stroke(GagColors.outlineVariant, lineWidth: 1)
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.horizontal, GagShapes.spacingL)
        .padding(.vertical, GagShapes.spacingXS)
    }
}

struct OrderStatusBadge: View {
    let status: OrderStatus
    
    var body: some View {
        Text(status.displayName)
            .font(GagTypography.labelSmall)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12))
            .clipShape(GagShapes.cornerRadius(GagShapes.radiusPill))
    }
    
    private var statusColor: Color {
        switch status {
        case .placed, .accepted: return GagColors.statusPlaced
        case .preparing: return GagColors.statusPreparing
        case .ready: return GagColors.statusReady
        case .pickedUp: return GagColors.statusPickedUp
        case .cancelled, .rejected, .expired: return GagColors.statusCancelled
        case .refunded: return GagColors.statusRefunded
        default: return GagColors.statusCreated
        }
    }
}

struct OrderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let order: OrderEntity
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GagShapes.spacingL) {
                    // Status header
                    VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                        HStack {
                            Text(order.orderNumber)
                                .font(GagTypography.titleMedium)
                                .foregroundStyle(GagColors.onSurface)
                            Spacer()
                            OrderStatusBadge(status: order.status)
                        }
                        
                        if let slot = order.pickupSlot {
                            Label(slot.displayTime, systemImage: "clock")
                                .font(GagTypography.bodyMedium)
                                .foregroundStyle(GagColors.onSurfaceVariant)
                        }
                    }
                    .gagCard()
                    .padding(.horizontal, GagShapes.spacingL)
                    
                    // Items
                    VStack(alignment: .leading, spacing: GagShapes.spacingM) {
                        Text("Items")
                            .font(GagTypography.titleMedium)
                            .foregroundStyle(GagColors.onSurface)
                            .padding(.horizontal, GagShapes.spacingL)
                        
                        ForEach(order.items) { item in
                            HStack(spacing: GagShapes.spacingM) {
                                Group {
                                    if let urlString = item.foodImageUrl, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            default:
                                                itemPlaceholder
                                            }
                                        }
                                    } else {
                                        itemPlaceholder
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(GagShapes.cornerRadius(GagShapes.radiusMedium))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        VegIndicator(isVeg: item.isVeg)
                                        Text(item.foodName)
                                            .font(GagTypography.bodyMedium)
                                            .foregroundStyle(GagColors.onSurface)
                                    }
                                    
                                    if !item.customizations.isEmpty {
                                        Text(item.customizations.joined(separator: ", "))
                                            .font(GagTypography.bodySmall)
                                            .foregroundStyle(GagColors.onSurfaceVariant)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("\(item.quantity) × \(Formatters.price(item.unitPrice))")
                                        .font(GagTypography.labelMedium)
                                        .foregroundStyle(GagColors.onSurface)
                                    Text(Formatters.price(item.unitPrice * Double(item.quantity)))
                                        .font(GagTypography.labelLarge)
                                        .foregroundStyle(GagColors.onSurface)
                                }
                            }
                            .padding(GagShapes.spacingM)
                            .background(GagColors.surface)
                            .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
                            .overlay(
                                GagShapes.cornerRadius(GagShapes.radiusLarge)
                                    .stroke(GagColors.outlineVariant, lineWidth: 1)
                            )
                            .padding(.horizontal, GagShapes.spacingL)
                        }
                    }
                    
                    // Summary
                    VStack(spacing: GagShapes.spacingS) {
                        SummaryRow(label: "Subtotal", value: order.subtotal)
                        SummaryRow(label: "Tax (5%)", value: order.tax)
                        Divider()
                        SummaryRow(label: "Total Paid", value: order.total, isTotal: true)
                    }
                    .gagCard()
                    .padding(.horizontal, GagShapes.spacingL)
                    
                    if let instructions = order.specialInstructions {
                        VStack(alignment: .leading, spacing: GagShapes.spacingS) {
                            Text("Special Instructions")
                                .font(GagTypography.labelLarge)
                                .foregroundStyle(GagColors.onSurface)
                            Text(instructions)
                                .font(GagTypography.bodyMedium)
                                .foregroundStyle(GagColors.onSurfaceVariant)
                        }
                        .gagCard()
                        .padding(.horizontal, GagShapes.spacingL)
                    }
                }
                .padding(.vertical, GagShapes.spacingM)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var itemPlaceholder: some View {
        ZStack {
            GagColors.surfaceVariant
            Image(systemName: "fork.knife")
                .foregroundStyle(GagColors.onSurfaceDim)
        }
    }
}
