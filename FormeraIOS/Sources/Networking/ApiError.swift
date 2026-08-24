import Foundation

/// Mirrors formera_client's lib/api.ts parseErrorBody(): DRF returns either
/// {"detail": "..."} for auth/permission errors, or
/// {"field_name": ["message", ...]} for serializer validation errors --
/// this surfaces the first field message so callers see something more
/// useful than a generic failure (e.g. "customer with this email already
/// exists"), while still exposing the full field map for inline form errors.
struct ApiError: Error, Equatable {
    let status: Int
    let message: String
    let fields: [String: [String]]?

    init(status: Int, data: Data) {
        self.status = status
        let (message, fields) = Self.parse(data)
        self.message = message
        self.fields = fields
    }

    // Dictionary key order isn't preserved through JSONSerialization, unlike
    // JS object insertion order -- so "first field" here is "some field",
    // picked deterministically by sorting keys rather than matching the
    // web's exact field-priority order.
    private static func parse(_ data: Data) -> (String, [String: [String]]?) {
        guard
            let json = try? JSONSerialization.jsonObject(with: data),
            let object = json as? [String: Any]
        else {
            return ("Request failed", nil)
        }

        if let detail = object["detail"] as? String {
            return (detail, nil)
        }

        var fields: [String: [String]] = [:]
        for (key, value) in object {
            if let messages = value as? [String] {
                fields[key] = messages
            }
        }
        if let firstKey = fields.keys.sorted().first, let firstMessage = fields[firstKey]?.first {
            return (firstMessage, fields)
        }
        return ("Request failed", nil)
    }
}

extension ApiError: LocalizedError {
    var errorDescription: String? { message }
}

extension APIError {
    var displayMessage: String {
        switch self {
        case .requestFailed(let apiError): apiError.message
        case .invalidURL, .encodingFailed, .decodingFailed: "Something went wrong."
        }
    }
}

/// Best-effort human-readable message for any thrown error -- unwraps the
/// APIClient's APIError.requestFailed(ApiError) shape when present, so
/// views/view models don't each need their own `as? APIError` dance.
/// Named apiErrorMessage (not errorMessage) since view models commonly have
/// their own `errorMessage` stored property, which would otherwise shadow a
/// same-named free function at the call site.
func apiErrorMessage(_ error: Error) -> String {
    (error as? APIError)?.displayMessage ?? "Something went wrong."
}
