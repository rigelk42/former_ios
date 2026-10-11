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

/// One Saturday-Friday week's sales total from GET /api/orders/weekly-sales/.
struct WeeklySalesItem: Decodable, Identifiable, Hashable {
    let weekStart: String
    // String for the same precision reason as SalesSummaryItem.revenue.
    let total: String

    var id: String { weekStart }

    var totalValue: Decimal { Decimal(string: total) ?? 0 }

    /// "Oct 10" -- the week's Saturday start, as the bar's axis label.
    var weekStartLabel: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: weekStart) else { return weekStart }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct WeeklySales: Decodable {
    let weeks: [WeeklySalesItem]
}
