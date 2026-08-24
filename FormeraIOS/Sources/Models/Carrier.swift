import Foundation

// Best-effort shape for ShipStation's GET /v2/carriers response -- there's
// no sandbox to verify field names against a real response ahead of time,
// so double check these against the actual payload on first live use
// (mirrors the same caveat in orders/types.ts).
struct CarrierService: Decodable, Hashable, Identifiable {
    let serviceCode: String
    let name: String

    var id: String { serviceCode }
}

struct Carrier: Decodable, Hashable, Identifiable {
    let carrierId: String
    let friendlyName: String
    let services: [CarrierService]

    var id: String { carrierId }
}

struct CarrierListResponse: Decodable {
    let carriers: [Carrier]
}
