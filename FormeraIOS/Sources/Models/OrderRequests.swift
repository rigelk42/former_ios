import Foundation

struct NewCustomerInput: Encodable {
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String
}

struct NewProductInput: Encodable {
    var name: String
    var price: Double
}

/// Exactly one of product/newProduct must be set, mirroring
/// CreateOrderInput's customerId/newCustomer split -- see
/// OrderLineItemCreateSerializer.validate() on the backend.
struct CreateOrderLineItemInput: Encodable {
    var product: Int?
    var newProduct: NewProductInput?
    var quantity: Int
    // Omit to default to the product's current catalog price server-side.
    // For a newProduct item, this is also that product's catalog price.
    var unitPrice: Double?
}

struct CreateOrderInput: Encodable {
    var customerId: Int?
    var newCustomer: NewCustomerInput?
    var shippingAddress: AddressInput?
    // Omit to default to "cash_pickup" server-side.
    var status: OrderStatus?
    var discount: Int?
    var items: [CreateOrderLineItemInput]
}

/// Include "id" to edit an existing line item's quantity/unitPrice, or omit
/// it to add a new one -- exactly one of product/newProduct is required in
/// that case, mirroring CreateOrderLineItemInput. This is a full replace of
/// the order's items: any existing item not included here gets removed --
/// see OrderUpdateSerializer._sync_items() on the backend.
struct UpdateOrderLineItemInput: Encodable {
    var id: Int?
    var product: Int?
    var newProduct: NewProductInput?
    var quantity: Int
    var unitPrice: Double?
}

/// Every field is optional -- send only what's changing. Locked
/// server-side once the order has an active shipping label (see
/// OrderDetailView.patch/OrderUpdateSerializer) -- void the shipment first
/// to edit again.
struct UpdateOrderInput: Encodable {
    var status: OrderStatus?
    /// .omit leaves the existing discount as-is; .value(nil) explicitly
    /// clears it; .value(x) sets it. See Omittable.swift.
    var discount: Omittable<Int> = .omit
    var shippingAddress: AddressInput?
    var items: [UpdateOrderLineItemInput]?

    private enum CodingKeys: String, CodingKey {
        case status, discount, shippingAddress, items
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(shippingAddress, forKey: .shippingAddress)
        try container.encodeIfPresent(items, forKey: .items)
        switch discount {
        case .omit:
            break
        case .value(let value):
            if let value {
                try container.encode(value, forKey: .discount)
            } else {
                try container.encodeNil(forKey: .discount)
            }
        }
    }
}

struct CreateShipmentInput: Encodable {
    var carrierId: String
    var carrierName: String
    var serviceCode: String
    var weightOz: Double
    var length: Double
    var width: Double
    var height: Double
}

/// Overrides a single line item's price on an already-placed order,
/// recomputing the order's total server-side.
struct UpdateLineItemPriceInput: Encodable {
    var unitPrice: Double
}

/// For POST endpoints the web calls with no request body at all (shipment
/// refresh/void) -- APIClient.post always encodes *some* body, so this
/// stands in as an empty one rather than adding a bodyless overload just
/// for two call sites.
struct EmptyBody: Encodable {}
