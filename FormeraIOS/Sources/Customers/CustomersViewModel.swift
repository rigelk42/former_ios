import Foundation
import Observation

/// Owns the customers list (mirrors the role formera_client's react-query
/// cache plays for CustomersPage/CustomerDetailModal/CustomerFormModal):
/// created once by CustomersListView and shared with detail/form screens so
/// a create/edit/delete there is reflected back in the list without a
/// separate refetch-on-navigate-back dance.
@MainActor
@Observable
final class CustomersViewModel {
    private(set) var customers: [Customer] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    /// Total customer count, independent of how many pages have loaded so
    /// far -- from a dedicated endpoint, since the list itself is cursor
    /// paginated and deliberately doesn't return a total (see
    /// DefaultCursorPagination on the backend). nil until refresh() loads it.
    private(set) var totalCount: Int?
    var searchText = ""

    private var nextCursor: String?
    private var hasLoadedOnce = false
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    /// Filters the already-loaded pages client-side -- same scope as the
    /// web's column search (getColumnSearchProps), which also only filters
    /// the currently-loaded page rather than hitting a server search endpoint.
    var filteredCustomers: [Customer] {
        guard !searchText.isEmpty else { return customers }
        return customers.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
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
            let page = try await apiClient.get("customers/", as: CursorPage<Customer>.self)
            customers = page.results
            nextCursor = cursorFromURL(page.next)
            hasLoadedOnce = true
        } catch {
            errorMessage = apiErrorMessage(error)
        }
        await loadTotalCount()
    }

    /// Best-effort: a failure here shouldn't block the list itself from
    /// showing (same reasoning as loadMoreIfNeeded's silent catch) --
    /// totalCount just stays at its last known value, or nil on first load.
    private func loadTotalCount() async {
        totalCount = try? await apiClient.get("customers/count/", as: CustomerCountResponse.self).count
    }

    func loadMoreIfNeeded(current customer: Customer) async {
        guard customer.id == customers.last?.id, let cursor = nextCursor, !isLoadingMore else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await apiClient.get("customers/\(cursorQuery(cursor))", as: CursorPage<Customer>.self)
            customers.append(contentsOf: page.results)
            nextCursor = cursorFromURL(page.next)
        } catch {
            // Silent -- the next scroll attempt or a pull-to-refresh retries;
            // surfacing a toast here would be noisy for a background page load.
        }
    }

    func fetchDetail(_ id: Int) async throws -> CustomerDetail {
        try await apiClient.get("customers/\(id)/", as: CustomerDetail.self)
    }

    func create(_ input: CreateCustomerInput) async throws -> CustomerDetail {
        let detail = try await apiClient.post("customers/", body: input, as: CustomerDetail.self)
        customers.insert(detail.asCustomer, at: 0)
        if let totalCount { self.totalCount = totalCount + 1 }
        return detail
    }

    func update(_ id: Int, _ input: UpdateCustomerInput) async throws -> CustomerDetail {
        let detail = try await apiClient.patch("customers/\(id)/", body: input, as: CustomerDetail.self)
        if let index = customers.firstIndex(where: { $0.id == id }) {
            customers[index] = detail.asCustomer
        }
        return detail
    }

    func delete(_ customer: Customer) async throws {
        try await apiClient.delete("customers/\(customer.id)/")
        customers.removeAll { $0.id == customer.id }
        if let totalCount { self.totalCount = totalCount - 1 }
    }

    func deleteAddress(customerId: Int, addressId: Int) async throws {
        try await apiClient.delete("customers/\(customerId)/addresses/\(addressId)/")
    }

    func createAddress(customerId: Int, _ input: AddressInput) async throws -> Address {
        try await apiClient.post("customers/\(customerId)/addresses/", body: input, as: Address.self)
    }

    func updateAddress(customerId: Int, addressId: Int, _ input: AddressInput) async throws -> Address {
        try await apiClient.patch("customers/\(customerId)/addresses/\(addressId)/", body: input, as: Address.self)
    }

    /// For populating a customer picker (e.g. the order form) rather than
    /// the paginated list -- 100 is the backend's max_page_size, the most
    /// this can fetch in one request without a dedicated search endpoint.
    func fetchOptions() async throws -> [Customer] {
        try await apiClient.get("customers/?page_size=100", as: CursorPage<Customer>.self).results
    }
}

private struct CustomerCountResponse: Decodable {
    let count: Int
}
