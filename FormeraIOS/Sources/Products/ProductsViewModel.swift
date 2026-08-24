import Foundation
import Observation

/// Owns the products list, same role CustomersViewModel plays for
/// customers. Note there's no update/edit here -- unlike customers/orders,
/// the web app never added a product edit flow (no updateProduct in
/// products/api.ts), so this only supports create/delete, matching scope.
@MainActor
@Observable
final class ProductsViewModel {
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    var searchText = ""

    private var nextCursor: String?
    private var hasLoadedOnce = false
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    var filteredProducts: [Product] {
        guard !searchText.isEmpty else { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
            let page = try await apiClient.get("products/", as: CursorPage<Product>.self)
            products = page.results
            nextCursor = cursorFromURL(page.next)
            hasLoadedOnce = true
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    func loadMoreIfNeeded(current product: Product) async {
        guard product.id == products.last?.id, let cursor = nextCursor, !isLoadingMore else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await apiClient.get("products/\(cursorQuery(cursor))", as: CursorPage<Product>.self)
            products.append(contentsOf: page.results)
            nextCursor = cursorFromURL(page.next)
        } catch {
            // Silent -- see CustomersViewModel.loadMoreIfNeeded for why.
        }
    }

    func fetchDetail(_ id: Int) async throws -> ProductDetail {
        try await apiClient.get("products/\(id)/", as: ProductDetail.self)
    }

    func create(_ input: CreateProductInput) async throws -> ProductDetail {
        let detail = try await apiClient.post("products/", body: input, as: ProductDetail.self)
        products.insert(detail.asProduct, at: 0)
        return detail
    }

    func delete(_ product: Product) async throws {
        try await apiClient.delete("products/\(product.id)/")
        products.removeAll { $0.id == product.id }
    }

    /// For populating a product picker (e.g. the order form) rather than
    /// the paginated list -- 100 is the backend's max_page_size.
    func fetchOptions() async throws -> [Product] {
        try await apiClient.get("products/?page_size=100", as: CursorPage<Product>.self).results
    }
}
