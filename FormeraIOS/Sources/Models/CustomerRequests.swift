import Foundation

struct CreateCustomerInput: Encodable {
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String
    var address: AddressInput?
}

/// Addresses/orders aren't editable through this endpoint (see
/// CustomerUpdateSerializer). Unlike UpdateOrderInput.discount, an edit
/// form here always submits the full current snapshot of every field
/// rather than a partial diff, so there's no separate "leave untouched"
/// state to represent -- but email must still be sent as an explicit null
/// (not omitted) when cleared, since it's nullable server-side, so this
/// writes its own encode(to:) rather than relying on Optional's default
/// encodeIfPresent-on-nil synthesis.
struct UpdateCustomerInput: Encodable {
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String

    private enum CodingKeys: String, CodingKey {
        case firstName, lastName, email, phone
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
    }
}

// Archiving a customer's address, like the customer itself, is a DELETE
// with no request body -- see AddressDetailView on the backend.
