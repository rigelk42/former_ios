import SwiftUI

/// Replaces ProductDetailModal.tsx as a pushed screen. No edit affordance
/// -- the web app never added a product edit flow either, only create and
/// delete.
struct ProductDetailView: View {
    let productId: Int
    var viewModel: ProductsViewModel

    @State private var detail: ProductDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isDeleteConfirming = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let detail {
                List {
                    Section {
                        LabeledContent("SKU", value: detail.sku)
                        LabeledContent("Price", value: detail.price.asCurrency)
                        LabeledContent("Stock", value: "\(detail.stock)")
                        if !detail.description.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description").foregroundStyle(.secondary)
                                Text(detail.description)
                            }
                        }
                    }

                    Section("Ingredients") {
                        if detail.dosages.isEmpty {
                            Text("No ingredients on file").foregroundStyle(.secondary)
                        }
                        ForEach(detail.dosages) { dosage in
                            LabeledContent(dosage.ingredientName, value: dosage.displayAmount)
                        }
                    }

                    Section {
                        Button("Delete Product", role: .destructive) {
                            isDeleteConfirming = true
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(detail?.name ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this product?",
            isPresented: $isDeleteConfirming,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            Text("It will be removed from the catalog and product pickers.")
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await viewModel.fetchDetail(productId)
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func performDelete() async {
        guard let product = detail?.asProduct else { return }
        do {
            try await viewModel.delete(product)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
