import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class OrdersViewModel {
    private let modelContext: ModelContext
    private(set) var orders: [OrderEntity] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadOrders()
    }
    
    func loadOrders() {
        let descriptor = FetchDescriptor<OrderEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            orders = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load orders: \(error)")
        }
    }
    
    func addOrder(_ order: OrderEntity) {
        modelContext.insert(order)
        orders.insert(order, at: 0)
        try? modelContext.save()
    }
}

@Model
final class OrderEntity {
    var id: String = UUID().uuidString
    var orderNumber: String
    var items: [OrderItemEntity]
    var subtotal: Double
    var tax: Double
    var total: Double
    var status: OrderStatus
    var pickupSlot: PickupSlot?
    var estimatedPrepMinutes: Int
    var actualPrepMinutes: Int?
    var createdAt: Date = Date()
    var placedAt: Date?
    var acceptedAt: Date?
    var preparingAt: Date?
    var readyAt: Date?
    var pickedUpAt: Date?
    var cancelledAt: Date?
    var cancellationReason: String?
    var paymentStatus: PaymentStatus
    var paymentMethod: PaymentMethod
    var specialInstructions: String?
    var qrToken: String?
    
    init(
        orderNumber: String,
        items: [OrderItemEntity],
        subtotal: Double,
        tax: Double,
        total: Double,
        status: OrderStatus,
        pickupSlot: PickupSlot?,
        estimatedPrepMinutes: Int,
        actualPrepMinutes: Int? = nil,
        paymentStatus: PaymentStatus,
        paymentMethod: PaymentMethod,
        specialInstructions: String? = nil,
        qrToken: String? = nil
    ) {
        self.orderNumber = orderNumber
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.status = status
        self.pickupSlot = pickupSlot
        self.estimatedPrepMinutes = estimatedPrepMinutes
        self.actualPrepMinutes = actualPrepMinutes
        self.paymentStatus = paymentStatus
        self.paymentMethod = paymentMethod
        self.specialInstructions = specialInstructions
        self.qrToken = qrToken
    }
}

@Model
final class OrderItemEntity {
    var id: String = UUID().uuidString
    var foodItemId: String
    var foodName: String
    var foodImageUrl: String?
    var quantity: Int
    var unitPrice: Double
    var customizations: [String]
    var isVeg: Bool
    
    init(
        foodItemId: String,
        foodName: String,
        foodImageUrl: String?,
        quantity: Int,
        unitPrice: Double,
        customizations: [String],
        isVeg: Bool
    ) {
        self.foodItemId = foodItemId
        self.foodName = foodName
        self.foodImageUrl = foodImageUrl
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.customizations = customizations
        self.isVeg = isVeg
    }
}
