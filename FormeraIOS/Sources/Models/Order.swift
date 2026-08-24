import Foundation

/// Mirrors orders/types.ts.
enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case paid
    case cashPickup = "cash_pickup"
    case venmo
    case referral

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paid: "Paid"
        case .cashPickup: "Cash pickup"
        case .venmo: "Venmo"
        case .referral: "Referral"
        }
    }
}

enum ShippingStatus: String, Codable {
    case notShipped = "not_shipped"
    case labelCreated = "label_created"
    case inTransit = "in_transit"
    case delivered
    case exception
    case voided

    var label: String {
        switch self {
        case .notShipped: "Not shipped"
        case .labelCreated: "Label created"
        case .inTransit: "In transit"
        case .delivered: "Delivered"
        case .exception: "Exception"
        case .voided: "Voided"
        }
    }
}

struct OrderLineItem: Decodable, Identifiable, Hashable {
    let id: Int
    let product: Int
    let productName: String
    let quantity: Int
    // DRF serializes DecimalField as a string to avoid float precision loss.
    let unitPrice: String
    let subtotal: String
}

struct Order: Decodable, Identifiable, Hashable {
    let id: Int
    let orderNumber: String
    let customer: Int
    let customerName: String
    let shippingAddress: AddressInput?
    let status: OrderStatus
    /// Whole-percent discount applied to the line item subtotal, 1-100.
    /// nil means no discount was applied.
    let discount: Int?
    // DRF serializes DecimalField as a string to avoid float precision loss.
    let totalAmount: String
    let items: [OrderLineItem]
    let createdAt: String
    let updatedAt: String
    let shippingStatus: ShippingStatus
    let carrierCode: String
    let carrierName: String
    let serviceCode: String
    let trackingNumber: String
    let labelUrl: String
    // DRF serializes DecimalField as a string; nil until a label exists.
    let shippingCost: String?
    let shippedAt: String?
}
