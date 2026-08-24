import Foundation

/// Mirrors lib/pagination.ts's CursorPage<T> -- the plain cursor-paginated
/// list shape shared by customers and products.
struct CursorPage<T: Decodable>: Decodable {
    let next: String?
    let previous: String?
    let results: [T]
}

/// One Monday-Sunday calendar week's worth of orders, as returned by the
/// backend's OrderWeekPagination -- grouping happens server-side so a week
/// is never split across two pages.
struct OrderWeekGroup: Decodable, Identifiable {
    let weekStart: String
    var orders: [Order]

    var id: String { weekStart }
}

/// The orders list endpoint's response shape, distinct from the plain
/// CursorPage<T> used by customers/products.
struct OrderWeekPage: Decodable {
    let next: String?
    let previous: String?
    let weeks: [OrderWeekGroup]
}

/// Mirrors lib/pagination.ts's cursorFromUrl(): the API returns full
/// next/previous URLs, but requesting the next page only needs the
/// "cursor" query param out of them.
func cursorFromURL(_ urlString: String?) -> String? {
    guard let urlString, let components = URLComponents(string: urlString) else {
        return nil
    }
    return components.queryItems?.first(where: { $0.name == "cursor" })?.value
}

/// Builds the "?cursor=..." query suffix for a page request, percent-encoding
/// the cursor value (mirrors the web's encodeURIComponent(cursor) in
/// customers/orders/products api.ts) -- empty for the first page.
func cursorQuery(_ cursor: String?) -> String {
    guard let cursor,
          let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    else {
        return ""
    }
    return "?cursor=\(encoded)"
}
