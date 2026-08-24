import Foundation

struct CreateProductInput: Encodable {
    var name: String
    var description: String
    var sku: String
    var price: String
    var stock: Int
    var dosages: [DosageInput]
}
