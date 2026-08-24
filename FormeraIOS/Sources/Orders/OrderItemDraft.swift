import Foundation

/// Editable state for one row of the create/edit order forms' dynamic line
/// items list -- mirrors OrderLineItemFields.tsx's OrderItemValue, unified
/// into one type shared by both OrderFormView (create) and OrderEditView
/// (edit) the way the web shares OrderLineItemFields between
/// OrderFormModal/OrderEditModal.
struct OrderItemDraft: Identifiable {
    let id = UUID()
    /// Set only when this row is an already-existing line item being
    /// edited -- its product can't be changed here, only quantity/price.
    var existingId: Int?
    var existingProductLabel: String?
    var mode: Mode = .existingProduct
    var selectedProductId: Int?
    var newProductName = ""
    var quantity = 1
    var unitPriceText = ""

    enum Mode {
        case existingProduct
        case newProduct
    }

    static func new() -> OrderItemDraft { OrderItemDraft() }

    static func from(_ item: OrderLineItem) -> OrderItemDraft {
        var draft = OrderItemDraft()
        draft.existingId = item.id
        draft.existingProductLabel = item.productName
        draft.quantity = item.quantity
        draft.unitPriceText = item.unitPrice
        return draft
    }

    var isValid: Bool {
        guard quantity > 0, Double(unitPriceText) != nil else { return false }
        guard existingId == nil else { return true }
        switch mode {
        case .existingProduct: return selectedProductId != nil
        case .newProduct: return !newProductName.isEmpty
        }
    }

    func toCreateInput() -> CreateOrderLineItemInput {
        let price = Double(unitPriceText)
        if existingId == nil, mode == .newProduct {
            return CreateOrderLineItemInput(
                product: nil,
                newProduct: NewProductInput(name: newProductName, price: price ?? 0),
                quantity: quantity,
                unitPrice: price
            )
        }
        return CreateOrderLineItemInput(
            product: selectedProductId,
            newProduct: nil,
            quantity: quantity,
            unitPrice: price
        )
    }

    /// Existing items only ever send id/quantity/unitPrice -- the product
    /// itself is immutable once ordered, matching OrderEditModal's
    /// handleFinish.
    func toUpdateInput() -> UpdateOrderLineItemInput {
        let price = Double(unitPriceText)
        if let existingId {
            return UpdateOrderLineItemInput(id: existingId, product: nil, newProduct: nil, quantity: quantity, unitPrice: price)
        }
        if mode == .newProduct {
            return UpdateOrderLineItemInput(
                id: nil,
                product: nil,
                newProduct: NewProductInput(name: newProductName, price: price ?? 0),
                quantity: quantity,
                unitPrice: price
            )
        }
        return UpdateOrderLineItemInput(id: nil, product: selectedProductId, newProduct: nil, quantity: quantity, unitPrice: price)
    }
}
