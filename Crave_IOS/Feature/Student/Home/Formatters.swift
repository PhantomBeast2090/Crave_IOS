import Foundation

enum Formatters {
    static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = AppConfig.currencyCode
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    static func price(_ value: Double) -> String {
        priceFormatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}
