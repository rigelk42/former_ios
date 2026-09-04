import Foundation

/// Mirrors orders/types.ts.
enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case paid
    case cashPickup = "cash_pickup"
    case standby
    case venmo
    case referral

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paid: "Paid"
        case .cashPickup: "Cash pickup"
        case .standby: "Standby"
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
    /// nil means no discount was applied. Mutually exclusive with
    /// discountAmount -- at most one is set. Named discountPercent on the
    /// Swift side for clarity even though the wire field is still just
    /// "discount" (kept as-is server-side to avoid a breaking rename for
    /// the web client, which reads/writes that same field).
    let discountPercent: Int?
    /// Fixed dollar-amount discount, as an alternative to discountPercent.
    /// DRF serializes DecimalField as a string to avoid float precision loss.
    let discountAmount: String?
    /// Free-form staff notes about this order. Same treatment as
    /// CustomerDetail.notes -- never nil, "" means no notes.
    let notes: String
    // DRF serializes DecimalField as a string to avoid float precision loss.
    let totalAmount: String
    let items: [OrderLineItem]
    /// The user-facing, editable order date -- a plain "YYYY-MM-DD" DRF
    /// DateField with no time component, distinct from createdAt below
    /// (an immutable audit timestamp). See DRFPlainDate for parsing this,
    /// not DRFDate. Displayed and edited via OrderDetailView/OrderEditView.
    let orderDate: String
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

    private enum CodingKeys: String, CodingKey {
        case id, orderNumber, customer, customerName, shippingAddress, status
        case discountPercent = "discount"
        case discountAmount, notes
        case totalAmount, items, orderDate, createdAt, updatedAt, shippingStatus
        case carrierCode, carrierName, serviceCode, trackingNumber, labelUrl
        case shippingCost, shippedAt
    }
}
