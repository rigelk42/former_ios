import Foundation

/// Shared across customers (a saved address) and orders (a shipping
/// address) -- both send/receive the identical shape. Mirrors
/// lib/types.ts's AddressInput; APIClient's snake_case key conversion
/// handles postalCode <-> postal_code.
struct AddressInput: Codable, Hashable {
    var line1: String
    var line2: String
    var city: String
    var state: String
    var postalCode: String
    var country: String
}
