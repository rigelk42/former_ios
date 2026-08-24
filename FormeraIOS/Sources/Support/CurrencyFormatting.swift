import Foundation

extension String {
    /// Parses a DRF DecimalField string (e.g. "19.99", serialized as a
    /// string server-side to avoid float precision loss) and formats it as
    /// USD -- falls back to the raw string if it isn't a valid decimal.
    var asCurrency: String {
        guard let value = Decimal(string: self) else { return self }
        return value.formatted(.currency(code: "USD"))
    }
}
