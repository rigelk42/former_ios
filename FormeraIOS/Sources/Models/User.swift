import Foundation

struct User: Decodable, Identifiable, Equatable {
    let id: Int
    let username: String
    let email: String
}
