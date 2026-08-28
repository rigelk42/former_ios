import Foundation
import Observation

/// Owns the dashboard's sales-per-item pie chart data for a selectable
/// date range, backed by the server-side aggregation at
/// GET /api/orders/sales-summary/ (see orders/views.py's
/// OrderSalesSummaryView) -- no client-side summing of order line items.
@MainActor
@Observable
final class DashboardViewModel {
    var startDate: Date
    var endDate: Date

    private(set) var items: [SalesSummaryItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        let calendar = Calendar.current
        let today = Date()
        startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        endDate = today
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let path = "orders/sales-summary/?start=\(Self.queryDate(startDate))&end=\(Self.queryDate(endDate))"
            let summary = try await apiClient.get(path, as: SalesSummary.self)
            items = summary.items
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private static func queryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
