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

    /// Last 10 weeks of money sold, oldest first (GET /api/orders/weekly-sales/).
    private(set) var weeklySales: [WeeklySalesItem] = []
    private(set) var weeklyErrorMessage: String?

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

    func loadWeekly() async {
        weeklyErrorMessage = nil
        do {
            weeklySales = try await apiClient.get("orders/weekly-sales/", as: WeeklySales.self).weeks
        } catch {
            weeklyErrorMessage = apiErrorMessage(error)
        }
    }

    private static func queryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
