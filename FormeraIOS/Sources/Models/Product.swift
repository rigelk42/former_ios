import Foundation

/// Mirrors products/types.ts.
struct Product: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String
    let sku: String
    // DRF serializes DecimalField as a string to avoid float precision loss.
    let price: String
    let stock: Int
    let createdAt: String
    let updatedAt: String
}

/// Only milligrams are supported by the backend today.
enum DosageUnit: String, Codable, CaseIterable, Identifiable {
    case mg

    var id: String { rawValue }
}

struct Dosage: Decodable, Identifiable, Hashable {
    let id: Int
    let product: Int
    let ingredient: Int
    let ingredientName: String
    let amount: String
    let unit: DosageUnit
    let displayAmount: String
}

struct DosageInput: Codable, Hashable, Identifiable {
    var id = UUID()
    var ingredientName: String
    var amount: String
    var unit: DosageUnit

    enum CodingKeys: String, CodingKey {
        case ingredientName, amount, unit
    }
}

struct ProductDetail: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String
    let sku: String
    let price: String
    let stock: Int
    let createdAt: String
    let updatedAt: String
    let dosages: [Dosage]

    var asProduct: Product {
        Product(
            id: id,
            name: name,
            description: description,
            sku: sku,
            price: price,
            stock: stock,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
