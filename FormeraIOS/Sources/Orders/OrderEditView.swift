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

    private enum DiscountType: String, CaseIterable, Identifiable {
        case percent, amount
        var id: String { rawValue }
        var label: String { self == .percent ? "Percentage" : "Fixed amount" }
    }

    @State private var orderDate: Date
    @State private var status: OrderStatus
    @State private var includeDiscount: Bool
    @State private var discountType: DiscountType
    @State private var discountPercent: Int
    @State private var discountAmountText: String
    @State private var notes: String
    @State private var includeAddress: Bool
    @State private var address: AddressInput
    @State private var productOptions: [Product] = []
    @State private var productsLoading = false
    @State private var items: [OrderItemDraft]
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var hasExistingAddress: Bool { order.shippingAddress != nil }
    private var isValid: Bool {
        let discountValid = !includeDiscount || discountType == .percent
            || (Double(discountAmountText).map { $0 > 0 } ?? false)
        return discountValid && items.allSatisfy(\.isValid)
    }

    /// Client-side preview of the server-computed total, so staff can see
    /// where the order lands while still editing items -- the real total
    /// is always recomputed server-side on submit (see
    /// Order.recompute_total on the backend).
    private var runningSubtotal: Decimal {
        items.reduce(Decimal(0)) { partial, item in
            guard let price = Decimal(string: item.unitPriceText) else { return partial }
            return partial + price * Decimal(item.quantity)
        }
    }

    private var runningTotal: Decimal {
        guard includeDiscount else { return runningSubtotal }
        switch discountType {
        case .percent:
            return (runningSubtotal * Decimal(100 - discountPercent) / Decimal(100))
        case .amount:
            guard let amount = Decimal(string: discountAmountText) else { return runningSubtotal }
            return max(runningSubtotal - amount, Decimal(0))
        }
    }

    init(order: Order, viewModel: OrdersViewModel, onUpdated: @escaping (Order) -> Void) {
        self.order = order
        self.viewModel = viewModel
        self.onUpdated = onUpdated
        // Falls back to today if order.orderDate can't be parsed -- should
        // never happen since the server always sends a valid DateField.
        _orderDate = State(initialValue: DRFPlainDate.parse(order.orderDate) ?? Date())
        _status = State(initialValue: order.status)
        _includeDiscount = State(initialValue: order.discountPercent != nil || order.discountAmount != nil)
        _discountType = State(initialValue: order.discountAmount != nil ? .amount : .percent)
        _discountPercent = State(initialValue: order.discountPercent ?? 10)
        _discountAmountText = State(initialValue: order.discountAmount ?? "")
        _notes = State(initialValue: order.notes)
        _includeAddress = State(initialValue: order.shippingAddress != nil)
        // Country has no field in AddressFormFields anymore (fixed to
        // "US"), so a pre-cleanup record's stale value (e.g. "United
        // States") is normalized here rather than silently round-tripped
        // back to the server unchanged.
        var seededAddress = order.shippingAddress ?? .empty
        seededAddress.country = "US"
        _address = State(initialValue: seededAddress)
        _items = State(initialValue: order.items.map(OrderItemDraft.from))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Order date", selection: $orderDate, displayedComponents: .date)
                }

                Section("Payment") {
                    Picker("Payment", selection: $status) {
                        ForEach(OrderStatus.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Toggle("Apply a discount", isOn: $includeDiscount.animation())
                    if includeDiscount {
                        Picker("Type", selection: $discountType) {
                            ForEach(DiscountType.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if discountType == .percent {
                            Stepper("Discount: \(discountPercent)%", value: $discountPercent, in: 1...100)
                        } else {
                            HStack {
                                Text("$")
                                TextField("Amount", text: $discountAmountText)
                                    .keyboardType(.decimalPad)
                            }
                        }
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

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section {
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
                } header: {
                    Text("Items")
                } footer: {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(runningTotal.formatted(.currency(code: "USD")))
                    }
                    .font(.subheadline.bold())
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
            .toast($errorMessage)
        }
    }

    private func loadProductOptions() async {
        productsLoading = true
        productOptions = ((try? await apiClient.get("products/?page_size=100", as: CursorPage<Product>.self))?.results ?? []).sortedForOrderPicker()
        productsLoading = false
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        // Discount is always sent explicitly (never omitted), same as the
        // web: unchecking the box, or switching between percent/amount,
        // needs to explicitly clear the inactive one rather than silently
        // leaving its old value in place.
        let input = UpdateOrderInput(
            status: status,
            orderDate: DRFPlainDate.format(orderDate),
            discountPercent: includeDiscount && discountType == .percent ? .value(discountPercent) : .value(nil),
            discountAmount: includeDiscount && discountType == .amount ? .value(Double(discountAmountText)) : .value(nil),
            notes: notes,
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
