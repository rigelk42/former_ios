import Foundation

/// Mirrors products/types.ts.
struct Product: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String
    let sku: String
    // DRF serializes DecimalField as a string to avoid float precision loss.
    let price: String
    let stock: Int
    let createdAt: String
    let updatedAt: String

    /// Bacteriostatic Water's catalog price is $0 (it's normally bundled
    /// in free with other products), but it's priced at $12 whenever it's
    /// added as its own line item on an order -- this overrides just that
    /// default-fill price, leaving the catalog price itself (shown on the
    /// Products tab, and the starting point for every other product)
    /// untouched. See OrderFormView.loadOptions and OrderLineItemRow.
    var defaultOrderUnitPrice: String {
        name.caseInsensitiveCompare("Bacteriostatic Water") == .orderedSame ? "12.00" : price
    }
}

/// Only milligrams are supported by the backend today.
enum DosageUnit: String, Codable, CaseIterable, Identifiable {
    case mg

    var id: String { rawValue }
}

struct Dosage: Decodable, Identifiable, Hashable {
    let id: Int
    let product: Int
    let ingredient: Int
    let ingredientName: String
    let amount: String
    let unit: DosageUnit
    let displayAmount: String
}

struct DosageInput: Codable, Hashable, Identifiable {
    var id = UUID()
    var ingredientName: String
    var amount: String
    var unit: DosageUnit

    enum CodingKeys: String, CodingKey {
        case ingredientName, amount, unit
    }
}

/// The products staff add to nearly every order -- pinned to the front (in
/// this order) of the order form's product picker, ahead of the rest of
/// the catalog. Matched case-insensitively since product names aren't
/// consistently cased in the catalog (e.g. "MOTS-c").
private let pinnedOrderProductNames = [
    "Retatrutide", "NAD+", "Bacteriostatic Water", "BPC-157", "TB-500", "MOTS-C",
]

extension [Product] {
    /// See OrderFormView/OrderEditView's loadOptions -- everything not in
    /// the pinned list keeps its existing (server-returned) relative order
    /// after the pinned products.
    func sortedForOrderPicker() -> [Product] {
        let rank = Dictionary(
            uniqueKeysWithValues: pinnedOrderProductNames.enumerated().map { ($1.lowercased(), $0) }
        )
        return enumerated()
            .sorted { lhs, rhs in
                let lhsRank = rank[lhs.element.name.lowercased()] ?? Int.max
                let rhsRank = rank[rhs.element.name.lowercased()] ?? Int.max
                return lhsRank != rhsRank ? lhsRank < rhsRank : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

struct ProductDetail: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String
    let sku: String
    let price: String
    let stock: Int
    let createdAt: String
    let updatedAt: String
    let dosages: [Dosage]

    var asProduct: Product {
        Product(
            id: id,
            name: name,
            description: description,
            sku: sku,
            price: price,
            stock: stock,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
