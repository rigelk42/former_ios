import Foundation

/// Mirrors orders/views.py's OrderSalesSummaryView response: total revenue
/// and quantity sold per product for a date range, most revenue first.
struct SalesSummaryItem: Decodable, Identifiable, Hashable {
    let productId: Int
    let productName: String
    let quantity: Int
    // DRF serializes DecimalField as a string to avoid float precision loss.
    let revenue: String

    var id: Int { productId }

    var revenueValue: Decimal { Decimal(string: revenue) ?? 0 }
}

struct SalesSummary: Decodable {
    let start: String
    let end: String
    let items: [SalesSummaryItem]
}
