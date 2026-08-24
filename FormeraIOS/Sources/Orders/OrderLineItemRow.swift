import SwiftUI

/// Replaces OrderLineItemFields.tsx.
private let newProductSentinel = -1

struct OrderLineItemRow: View {
    @Binding var draft: OrderItemDraft
    var productOptions: [Product]
    var productsLoading: Bool
    var onRemove: () -> Void
    var removeDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = draft.existingProductLabel {
                Text(label)
            } else if draft.mode == .newProduct {
                TextField("New product name", text: $draft.newProductName)
                Button("Choose an existing product instead") {
                    draft.mode = .existingProduct
                    draft.newProductName = ""
                    draft.selectedProductId = nil
                }
                .font(.footnote)
            } else {
                Picker("Product", selection: $draft.selectedProductId) {
                    Text(productsLoading ? "Loading…" : "Select a product").tag(Int?.none)
                    ForEach(productOptions) { product in
                        Text("\(product.name) — \(product.price.asCurrency)").tag(Optional(product.id))
                    }
                    Text("+ Add new product").tag(Optional(newProductSentinel))
                }
                .onChange(of: draft.selectedProductId) { _, newValue in
                    if newValue == newProductSentinel {
                        draft.mode = .newProduct
                        draft.selectedProductId = nil
                        draft.unitPriceText = ""
                    } else if let id = newValue, let product = productOptions.first(where: { $0.id == id }) {
                        draft.unitPriceText = product.price
                    }
                }
            }

            HStack {
                Stepper("Qty: \(draft.quantity)", value: $draft.quantity, in: 1...9999)
                Spacer()
                HStack(spacing: 4) {
                    Text("$")
                    TextField(draft.mode == .newProduct ? "New price" : "Price", text: $draft.unitPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                if !removeDisabled {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "minus.circle")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
