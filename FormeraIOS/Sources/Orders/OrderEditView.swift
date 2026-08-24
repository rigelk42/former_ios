import SwiftUI

/// Replaces OrderEditModal.tsx. Only reachable while the order is
/// editable (see OrderDetailView's isEditable check) -- locked server-side
/// once there's an active shipping label.
struct OrderEditView: View {
    let order: Order
    var viewModel: OrdersViewModel
    var onUpdated: (Order) -> Void

    @Environment(\.dismiss) private var dismiss
    private let apiClient = APIClient()

    @State private var status: OrderStatus
    @State private var includeDiscount: Bool
    @State private var discount: Int
    @State private var includeAddress: Bool
    @State private var address: AddressInput
    @State private var productOptions: [Product] = []
    @State private var productsLoading = false
    @State private var items: [OrderItemDraft]
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var hasExistingAddress: Bool { order.shippingAddress != nil }
    private var isValid: Bool { items.allSatisfy(\.isValid) }

    init(order: Order, viewModel: OrdersViewModel, onUpdated: @escaping (Order) -> Void) {
        self.order = order
        self.viewModel = viewModel
        self.onUpdated = onUpdated
        _status = State(initialValue: order.status)
        _includeDiscount = State(initialValue: order.discount != nil)
        _discount = State(initialValue: order.discount ?? 10)
        _includeAddress = State(initialValue: order.shippingAddress != nil)
        _address = State(initialValue: order.shippingAddress ?? .empty)
        _items = State(initialValue: order.items.map(OrderItemDraft.from))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                Section("Payment") {
                    Picker("Payment", selection: $status) {
                        ForEach(OrderStatus.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Toggle("Apply a discount", isOn: $includeDiscount.animation())
                    if includeDiscount {
                        Stepper("Discount: \(discount)%", value: $discount, in: 1...100)
                    }
                }

                Section("Shipping address") {
                    if hasExistingAddress {
                        AddressFormFields(address: $address)
                    } else {
                        Toggle("Add a shipping address", isOn: $includeAddress.animation())
                        if includeAddress {
                            AddressFormFields(address: $address)
                        }
                    }
                }

                Section("Items") {
                    ForEach($items) { $item in
                        OrderLineItemRow(
                            draft: $item,
                            productOptions: productOptions,
                            productsLoading: productsLoading,
                            onRemove: { items.removeAll { $0.id == item.id } },
                            removeDisabled: items.count == 1
                        )
                    }
                    Button {
                        items.append(.new())
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Edit \(order.orderNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await submit() } }
                        .disabled(!isValid || isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .task { await loadProductOptions() }
        }
    }

    private func loadProductOptions() async {
        productsLoading = true
        productOptions = (try? await apiClient.get("products/?page_size=100", as: CursorPage<Product>.self))?.results ?? []
        productsLoading = false
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        // Discount is always sent explicitly (never omitted), same as the
        // web: unchecking the box after a discount was previously applied
        // needs to explicitly clear it, not silently leave the old value.
        let input = UpdateOrderInput(
            status: status,
            discount: includeDiscount ? .value(discount) : .value(nil),
            shippingAddress: (hasExistingAddress || includeAddress) ? address : nil,
            items: items.map { $0.toUpdateInput() }
        )

        do {
            let updated = try await viewModel.update(order.id, input)
            onUpdated(updated)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
