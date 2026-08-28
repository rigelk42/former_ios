import Foundation

extension String {
    /// Formats a US phone number as "(619) 999-9999" -- strips everything
    /// but digits first, so it handles however the number happens to be
    /// stored (bare "6199999999", "+1 (619) 999-9999", "1-619-999-9999",
    /// etc.) the same way. Falls back to the raw string for anything that
    /// isn't a recognizable 10-digit US number (an 11-digit number is only
    /// unwrapped when it carries the "1" country code prefix).
    var formattedAsPhone: String {
        var digits = filter(\.isNumber)
        if digits.count == 11, digits.first == "1" {
            digits.removeFirst()
        }
        guard digits.count == 10 else { return self }

        let area = digits.prefix(3)
        let exchange = digits.dropFirst(3).prefix(3)
        let line = digits.suffix(4)
        return "(\(area)) \(exchange)-\(line)"
    }
}
