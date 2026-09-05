import Foundation

/// Formatting helpers for prices, dates, and times. Kept simple and locale-aware.
nonisolated enum Formatters {
    /// Format a rupee amount, e.g. "₹123.50".
    static func price(_ value: Double) -> String {
        priceFormatter.string(from: NSDecimalNumber(value: value)) ?? "₹\(value)"
    }

    /// Format an amount given in paise (Razorpay), e.g. 12350 → "₹123.50".
    static func price(paise: Int) -> String {
        price(Double(paise) / 100)
    }

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = AppConfig.currencyCode
        f.locale = Locale(identifier: "en_IN")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// "12:30" → "12:30 PM"
    static func time(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return hhmm }
        let hour = h % 12 == 0 ? 12 : h % 12
        let suffix = h < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour, m, suffix)
    }

    /// "2024-01-15" → "Mon, 15 Jan"
    static func slotDate(_ isoDate: String) -> String {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
        else { return isoDate }

        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        let monthName = DateFormatter()
        monthName.dateFormat = "d MMM"
        return "\(weekday.string(from: date)), \(monthName.string(from: date))"
    }

    /// ISO8601 timestamp → relative "5m ago" / "2h ago" / fallback to short date.
    static func relativeTime(_ iso: String) -> String {
        guard let date = iso8601.date(from: iso) else { return shortDate(iso) }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func shortDate(_ iso: String) -> String {
        if iso.count >= 10 { return String(iso.prefix(10)) }
        return iso
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
