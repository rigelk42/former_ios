import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable {
    let user: User
    let access: String
    let refresh: String
}

struct RefreshRequest: Encodable {
    let refresh: String
}

struct RefreshResponse: Decodable {
    let access: String
    let refresh: String
}
