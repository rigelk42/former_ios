import Foundation

/// Parses DRF's ISO 8601 timestamp strings (created_at/updated_at/shipped_at),
/// which include fractional seconds -- the plain ISO8601DateFormatter()
/// default doesn't accept those unless withFractionalSeconds is set. Falls
/// back to the no-fractional-seconds variant for the rare timestamp that
/// lands on an exact second.
enum DRFDate {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        withFractionalSeconds.date(from: string) ?? withoutFractionalSeconds.date(from: string)
    }
}

extension String {
    /// Formats a DRF timestamp string for display, falling back to the raw
    /// string if it can't be parsed.
    func formattedAsDate(date dateStyle: Date.FormatStyle.DateStyle = .abbreviated, time timeStyle: Date.FormatStyle.TimeStyle = .omitted) -> String {
        guard let parsed = DRFDate.parse(self) else { return self }
        return parsed.formatted(date: dateStyle, time: timeStyle)
    }
}

/// order_date is a DRF DateField ("2026-03-15") rather than a full
/// timestamp -- it has no time-of-day or time zone component at all, so
/// converting it through DRFDate.parse's UTC-anchored ISO 8601 formatter
/// would shift it to the wrong calendar day on devices behind UTC. These
/// build/read the Date using the device's own current calendar on both
/// ends instead, so the day never moves.
enum DRFPlainDate {
    static func parse(_ string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        (components.year, components.month, components.day) = (parts[0], parts[1], parts[2])
        return Calendar.current.date(from: components)
    }

    static func format(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension String {
    /// Formats a DRF DateField string (order_date) for display, falling
    /// back to the raw string if it can't be parsed.
    func formattedAsPlainDate(date dateStyle: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        guard let parsed = DRFPlainDate.parse(self) else { return self }
        return parsed.formatted(date: dateStyle, time: .omitted)
    }
}
