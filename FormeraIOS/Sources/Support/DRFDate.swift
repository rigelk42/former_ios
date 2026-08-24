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
