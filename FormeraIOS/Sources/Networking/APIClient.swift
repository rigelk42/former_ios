import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(ApiError)
    case encodingFailed(Error)
    case decodingFailed(Error)
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIClient {
    /// Set per-configuration by the API_BASE_URL build setting (see
    /// project.yml): Debug points at the local Django dev server, Release
    /// at the production Cloud Run deployment, via the APIBaseURL Info.plist
    /// key.
    ///
    /// Trailing slash matters: URL(string:relativeTo:) resolves a relative
    /// path against everything but the base's last path segment, so without
    /// it "products/" resolves to ".../formera-api-833262393415.us-west2.run.app/products/"
    /// instead of ".../api/products/".
    static let baseURL: URL = {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: string) else {
            fatalError("Missing or invalid APIBaseURL in Info.plist")
        }
        return url
    }()

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

    func patch<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        as type: Response.Type
    ) async throws -> Response {
        let bodyData = try encode(body)
        let data = try await sendRaw(path, method: .patch, bodyData: bodyData, contentType: "application/json", authenticated: true)
        return try decode(data)
    }

    /// Every business resource is soft-deleted server-side (see the
    /// "archive not delete" note in the migration plan), but the HTTP verb
    /// is still DELETE and the response is 204 -- no body to decode.
    func delete(_ path: String) async throws {
        _ = try await sendRaw(path, method: .delete, bodyData: nil, contentType: nil, authenticated: true)
    }

    /// For an endpoint that returns a file (e.g. the order invoice PDF)
    /// rather than JSON -- reuses the same auth/refresh handling as the
    /// JSON methods, just skips decoding and surfaces the server-suggested
    /// filename instead. Mirrors lib/api.ts's apiFetchBlob.
    func getBlob(_ path: String) async throws -> (data: Data, filename: String?) {
        let (data, response) = try await sendRawFull(path, method: .get, bodyData: nil, contentType: nil, authenticated: true)
        let filename = response.value(forHTTPHeaderField: "Content-Disposition").flatMap(Self.filename(fromContentDisposition:))
        return (data, filename)
    }

    private static func filename(fromContentDisposition header: String) -> String? {
        guard let range = header.range(of: "filename=\"?") else { return nil }
        let rest = header[range.upperBound...]
        let name = rest.prefix { $0 != "\"" }
        return name.isEmpty ? nil : String(name)
    }

    // MARK: - Core

    private func sendRaw(
        _ path: String,
        method: HTTPMethod,
        bodyData: Data?,
        contentType: String?,
        authenticated: Bool
    ) async throws -> Data {
        try await sendRawFull(path, method: method, bodyData: bodyData, contentType: contentType, authenticated: authenticated).data
    }

    private func sendRawFull(
        _ path: String,
        method: HTTPMethod,
        bodyData: Data?,
        contentType: String?,
        authenticated: Bool,
        isRetry: Bool = false
    ) async throws -> (data: Data, response: HTTPURLResponse) {
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
            throw APIError.requestFailed(ApiError(status: -1, data: data))
        }

        // A 401 on an authenticated request means the access token expired
        // (they're short-lived by design). Refresh once and retry, rather
        // than surfacing a spurious failure to the caller.
        if httpResponse.statusCode == 401, authenticated, !isRetry,
           await AuthSession.shared.refreshAccessToken() {
            return try await sendRawFull(path, method: method, bodyData: bodyData, contentType: contentType, authenticated: authenticated, isRetry: true)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed(ApiError(status: httpResponse.statusCode, data: data))
        }

        return (data, httpResponse)
    }

    private func encode(_ body: some Encodable) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return try encoder.encode(body)
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
