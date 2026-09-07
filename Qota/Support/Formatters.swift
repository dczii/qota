import Foundation

enum ResetFormat {
    static func compact(_ date: Date?) -> String {
        guard let date else { return "" }
        let seconds = Int(date.timeIntervalSinceNow)
        if seconds <= 0 { return "soon" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days >= 2 { return "\(days)d" }
        if days >= 1 { return "\(days)d \(hours)h" }
        if hours >= 1 { return "\(hours)h \(minutes)m" }
        return "\(max(minutes, 1))m"
    }
}

enum PercentFormat {
    static func used(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// Cursor/Claude sometimes send 0...1, sometimes 0...100.
    static func normalized(_ raw: Double) -> Double {
        let percent = raw <= 1.0 ? raw * 100.0 : raw
        return min(100, max(0, percent))
    }
}

enum MoneyFormat {
    static func usd(cents: Double) -> String {
        let dollars = cents / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = dollars.rounded() == dollars ? 0 : 2
        return formatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
    }
}

enum FlexDate {
    static func parse(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let number = value as? NSNumber {
            return fromEpoch(number.doubleValue)
        }
        if let number = value as? Double {
            return fromEpoch(number)
        }
        if let number = value as? Int {
            return fromEpoch(Double(number))
        }
        if let string = value as? String {
            if let number = Double(string) {
                return fromEpoch(number)
            }
            return iso8601(string)
        }
        return nil
    }

    private static func fromEpoch(_ raw: Double) -> Date? {
        if raw > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: raw / 1000.0)
        }
        if raw > 1_000_000_000 {
            return Date(timeIntervalSince1970: raw)
        }
        return nil
    }

    private static func iso8601(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        if let date = basic.date(from: string) { return date }

        let posix = DateFormatter()
        posix.locale = Locale(identifier: "en_US_POSIX")
        posix.timeZone = TimeZone(secondsFromGMT: 0)
        posix.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return posix.date(from: string)
    }
}
