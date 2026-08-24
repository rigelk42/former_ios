import Foundation
import Observation

/// Owns the week-grouped orders list, plus every order mutation
/// (create/update/delete/line-item price/shipment) so a change made from
/// the detail screen is reflected back into the list in place -- mirrors
/// how OrderDetailModal.tsx's local `liveOrder` override and the list's
/// query cache stay in sync on the web.
@MainActor
@Observable
final class OrdersViewModel {
    private(set) var weeks: [OrderWeekGroup] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private var nextCursor: String?
    private var hasLoadedOnce = false
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func loadInitial() async {
        guard !hasLoadedOnce else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await apiClient.get("orders/", as: OrderWeekPage.self)
            weeks = page.weeks
            nextCursor = cursorFromURL(page.next)
            hasLoadedOnce = true
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    func loadMoreIfNeeded(current order: Order) async {
        guard order.id == weeks.last?.orders.last?.id, let cursor = nextCursor, !isLoadingMore else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await apiClient.get("orders/\(cursorQuery(cursor))", as: OrderWeekPage.self)
            weeks.append(contentsOf: page.weeks)
            nextCursor = cursorFromURL(page.next)
        } catch {
            // Silent -- see CustomersViewModel.loadMoreIfNeeded for why.
        }
    }

    /// A new order can land in a week bucket that isn't loaded yet (or
    /// didn't exist as a section before), so re-deriving that client-side
    /// would risk drifting from the server's own week grouping -- simplest
    /// correct thing is to reload from the top.
    func create(_ input: CreateOrderInput) async throws -> Order {
        let order = try await apiClient.post("orders/", body: input, as: Order.self)
        await refresh()
        return order
    }

    func update(_ id: Int, _ input: UpdateOrderInput) async throws -> Order {
        let updated = try await apiClient.patch("orders/\(id)/", body: input, as: Order.self)
        replace(updated)
        return updated
    }

    func updateLineItemPrice(orderId: Int, itemId: Int, unitPrice: Double) async throws -> Order {
        let updated = try await apiClient.patch(
            "orders/\(orderId)/items/\(itemId)/",
            body: UpdateLineItemPriceInput(unitPrice: unitPrice),
            as: Order.self
        )
        replace(updated)
        return updated
    }

    func delete(_ order: Order) async throws {
        try await apiClient.delete("orders/\(order.id)/")
        removeFromWeeks(orderId: order.id)
    }

    func createShipment(orderId: Int, input: CreateShipmentInput) async throws -> Order {
        let updated = try await apiClient.post("orders/\(orderId)/shipment/", body: input, as: Order.self)
        replace(updated)
        return updated
    }

    func refreshShipment(orderId: Int) async throws -> Order {
        let updated = try await apiClient.post("orders/\(orderId)/shipment/refresh/", body: EmptyBody(), as: Order.self)
        replace(updated)
        return updated
    }

    func voidShipment(orderId: Int) async throws -> Order {
        let updated = try await apiClient.post("orders/\(orderId)/shipment/void/", body: EmptyBody(), as: Order.self)
        replace(updated)
        return updated
    }

    func fetchCarriers() async throws -> [Carrier] {
        try await apiClient.get("shipstation/carriers/", as: CarrierListResponse.self).carriers
    }

    func fetchInvoice(orderId: Int) async throws -> (data: Data, filename: String?) {
        try await apiClient.getBlob("orders/\(orderId)/invoice/")
    }

    private func replace(_ updated: Order) {
        for weekIndex in weeks.indices {
            if let orderIndex = weeks[weekIndex].orders.firstIndex(where: { $0.id == updated.id }) {
                weeks[weekIndex].orders[orderIndex] = updated
                return
            }
        }
    }

    private func removeFromWeeks(orderId: Int) {
        for weekIndex in weeks.indices {
            weeks[weekIndex].orders.removeAll { $0.id == orderId }
        }
        weeks.removeAll { $0.orders.isEmpty }
    }
}
