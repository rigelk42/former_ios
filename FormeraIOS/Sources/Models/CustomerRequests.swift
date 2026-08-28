import Foundation

struct CreateCustomerInput: Encodable {
    var firstName: String
    var lastName: String
    var phone: String
    var notes: String
    var address: AddressInput?
}

/// Addresses/orders aren't editable through this endpoint (see
/// CustomerUpdateSerializer). An edit form here always submits the full
/// current snapshot of every field rather than a partial diff, so there's
/// no separate "leave untouched" state to represent.
struct UpdateCustomerInput: Encodable {
    var firstName: String
    var lastName: String
    var phone: String
    var notes: String
}

// Archiving a customer's address, like the customer itself, is a DELETE
// with no request body -- see AddressDetailView on the backend.
