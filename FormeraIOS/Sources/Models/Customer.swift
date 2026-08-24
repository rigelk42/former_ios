import Foundation

/// Mirrors customers/types.ts.
struct Customer: Decodable, Identifiable, Hashable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String
    let createdAt: String
    let updatedAt: String

    var fullName: String { "\(firstName) \(lastName)" }
}

struct Address: Decodable, Identifiable, Hashable {
    let id: Int
    let line1: String
    let line2: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let createdAt: String
    let updatedAt: String

    var singleLine: String {
        let secondLine = line2.isEmpty ? "" : ", \(line2)"
        return "\(line1)\(secondLine), \(city), \(state) \(postalCode)"
    }

    var asInput: AddressInput {
        AddressInput(line1: line1, line2: line2, city: city, state: state, postalCode: postalCode, country: country)
    }
}

struct CustomerDetail: Decodable, Identifiable, Hashable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String
    let createdAt: String
    let updatedAt: String
    let addresses: [Address]
    let orders: [Order]

    var fullName: String { "\(firstName) \(lastName)" }

    var asCustomer: Customer {
        Customer(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
