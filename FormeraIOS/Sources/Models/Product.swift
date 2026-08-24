import Foundation

struct Product: Decodable, Identifiable {
    let id: Int
    let name: String
    let sku: String
    let price: String
    let stock: Int
}
