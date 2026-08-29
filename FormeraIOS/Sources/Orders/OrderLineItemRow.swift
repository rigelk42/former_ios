import SwiftUI

/// Replaces OrderLineItemFields.tsx.
struct OrderLineItemRow: View {
    @Binding var draft: OrderItemDraft
    var productOptions: [Product]
    var productsLoading: Bool
    var onRemove: () -> Void
    var removeDisabled: Bool

    /// Local to this row -- cleared once a product is picked, so re-opening
    /// the search (via "Change") always starts blank rather than reshowing
    /// the previous query.
    @State private var searchText = ""

    /// Quick picks shown before the user types anything -- same pinned
    /// products the old Picker led with, capped so an empty query doesn't
    /// dump the whole catalog inline into the form.
    private static let quickPickCount = 6

    private var selectedProduct: Product? {
        guard let id = draft.selectedProductId else { return nil }
        return productOptions.first { $0.id == id }
    }

    private var searchResults: [Product] {
        guard !searchText.isEmpty else { return Array(productOptions.prefix(Self.quickPickCount)) }
        return productOptions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.sku.localizedCaseInsensitiveContains(searchText)
        }
    }

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
            } else if let selected = selectedProduct {
                HStack {
                    Text("\(selected.name) — \(selected.price.asCurrency)")
                    Spacer()
                    Button("Change") {
                        draft.selectedProductId = nil
                        searchText = ""
                    }
                    .font(.footnote)
                }
            } else {
                TextField(productsLoading ? "Loading…" : "Search products", text: $searchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                ForEach(searchResults) { product in
                    Button {
                        draft.selectedProductId = product.id
                        draft.unitPriceText = product.defaultOrderUnitPrice
                        searchText = ""
                    } label: {
                        Text("\(product.name) — \(product.price.asCurrency)")
                    }
                }
                if !searchText.isEmpty, searchResults.isEmpty, !productsLoading {
                    Text("No products match \"\(searchText)\"")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    draft.mode = .newProduct
                    draft.newProductName = searchText
                    draft.selectedProductId = nil
                    draft.unitPriceText = ""
                } label: {
                    Label("Add new product", systemImage: "plus")
                }
                .font(.footnote)
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
