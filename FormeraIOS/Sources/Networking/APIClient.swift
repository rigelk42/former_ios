import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Int, Data)
    case encodingFailed(Error)
    case decodingFailed(Error)
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct APIClient {
    /// Points at the local Django dev server. Update for staging/production
    /// or move this behind an xcconfig-driven build setting later.
    ///
    /// Trailing slash matters: URL(string:relativeTo:) resolves a relative
    /// path against everything but the base's last path segment, so without
    /// it "products/" resolves to "127.0.0.1:8000/products/" instead of
    /// ".../api/products/".
    static let baseURL = URL(string: "http://127.0.0.1:8000/api/")!

    private let tokenStore: TokenStore

    init(tokenStore: TokenStore = .shared) {
        self.tokenStore = tokenStore
    }

    func get<Response: Decodable>(_ path: String, as type: Response.Type) async throws -> Response {
        let data = try await sendRaw(path, method: .get, bodyData: nil, contentType: nil, authenticated: true)
        return try decode(data)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        authenticated: Bool = false,
        as type: Response.Type
    ) async throws -> Response {
        let bodyData = try encode(body)
        let data = try await sendRaw(path, method: .post, bodyData: bodyData, contentType: "application/json", authenticated: authenticated)
        return try decode(data)
    }

    /// For endpoints whose response body isn't needed (e.g. logout's 204).
    @discardableResult
    func post<Body: Encodable>(_ path: String, body: Body, authenticated: Bool = false) async throws -> Data {
        let bodyData = try encode(body)
        return try await sendRaw(path, method: .post, bodyData: bodyData, contentType: "application/json", authenticated: authenticated)
    }

    // MARK: - Core

    private func sendRaw(
        _ path: String,
        method: HTTPMethod,
        bodyData: Data?,
        contentType: String?,
        authenticated: Bool,
        isRetry: Bool = false
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: Self.baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = bodyData
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = tokenStore.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed(-1, data)
        }

        // A 401 on an authenticated request means the access token expired
        // (they're short-lived by design). Refresh once and retry, rather
        // than surfacing a spurious failure to the caller.
        if httpResponse.statusCode == 401, authenticated, !isRetry,
           await AuthSession.shared.refreshAccessToken() {
            return try await sendRaw(path, method: method, bodyData: bodyData, contentType: contentType, authenticated: authenticated, isRetry: true)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed(httpResponse.statusCode, data)
        }

        return data
    }

    private func encode(_ body: some Encodable) throws -> Data {
        do {
            return try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingFailed(error)
        }
    }

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}
