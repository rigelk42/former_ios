import SwiftUI

/// Replaces OrderFormModal.tsx.
struct OrderFormView: View {
    var viewModel: OrdersViewModel
    var onCreated: ((Order) -> Void)?

    private enum CustomerMode: String, CaseIterable, Identifiable {
        case existing, new
        var id: String { rawValue }
        var label: String { self == .existing ? "Existing customer" : "New customer" }
    }

    private enum AddressMode: String, CaseIterable, Identifiable {
        case existing, new
        var id: String { rawValue }
        var label: String { self == .existing ? "Use existing address" : "Enter new address" }
    }

    private enum DiscountType: String, CaseIterable, Identifiable {
        case percent, amount
        var id: String { rawValue }
        var label: String { self == .percent ? "Percentage" : "Fixed amount" }
    }

    @Environment(\.dismiss) private var dismiss
    private let apiClient = APIClient()

    /// Quick picks shown before the user types anything -- mirrors
    /// OrderLineItemRow's product search.
    private static let quickPickCount = 6

    @State private var status: OrderStatus = .cashPickup
    @State private var customerMode: CustomerMode = .existing
    @State private var customerOptions: [Customer] = []
    @State private var customersLoading = false
    @State private var customerSearchText = ""
    @State private var selectedCustomerId: Int?
    @State private var selectedCustomerDetail: CustomerDetail?

    @State private var newFirstName = ""
    @State private var newLastName = ""
    @State private var newPhone = ""

    @State private var includeAddress = false
    @State private var addressMode: AddressMode = .new
    @State private var selectedAddressId: Int?
    @State private var address = AddressInput.empty

    @State private var includeDiscount = false
    @State private var discountType: DiscountType = .percent
    @State private var discountPercent = 10
    @State private var discountAmountText = ""

    @State private var notes = ""

    @State private var productOptions: [Product] = []
    @State private var productsLoading = false
    @State private var items: [OrderItemDraft] = [.new()]

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var selectedCustomer: Customer? {
        guard let id = selectedCustomerId else { return nil }
        return customerOptions.first { $0.id == id }
    }

    private var customerSearchResults: [Customer] {
        guard !customerSearchText.isEmpty else { return Array(customerOptions.prefix(Self.quickPickCount)) }
        return customerOptions.filter {
            $0.fullName.localizedCaseInsensitiveContains(customerSearchText) || $0.phone.localizedCaseInsensitiveContains(customerSearchText)
        }
    }

    private var existingAddresses: [Address] { selectedCustomerDetail?.addresses ?? [] }
    private var canUseExistingAddress: Bool { customerMode == .existing && !existingAddresses.isEmpty }

    private var isValid: Bool {
        let customerValid = customerMode == .existing ? selectedCustomerId != nil : !newFirstName.isEmpty
        let addressValid = !includeAddress
            || (addressMode == .existing && canUseExistingAddress ? selectedAddressId != nil : true)
        let discountValid = !includeDiscount || discountType == .percent
            || (Double(discountAmountText).map { $0 > 0 } ?? false)
        return customerValid && addressValid && discountValid && items.allSatisfy(\.isValid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment") {
                    Picker("Payment", selection: $status) {
                        ForEach(OrderStatus.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Customer") {
                    Picker("Customer", selection: $customerMode) {
                        ForEach(CustomerMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if customerMode == .existing {
                        if let selectedCustomer {
                            HStack {
                                Text("\(selectedCustomer.fullName) — \(selectedCustomer.phone)")
                                Spacer()
                                Button("Change") {
                                    selectedCustomerId = nil
                                    customerSearchText = ""
                                }
                                .font(.footnote)
                            }
                        } else {
                            TextField(customersLoading ? "Loading…" : "Search customers", text: $customerSearchText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            ForEach(customerSearchResults) { customer in
                                Button {
                                    selectedCustomerId = customer.id
                                    customerSearchText = ""
                                } label: {
                                    Text("\(customer.fullName) — \(customer.phone)")
                                }
                            }
                            if !customerSearchText.isEmpty, customerSearchResults.isEmpty, !customersLoading {
                                Text("No customers match \"\(customerSearchText)\"")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        TextField("First name", text: $newFirstName).textContentType(.givenName)
                        TextField("Last name", text: $newLastName).textContentType(.familyName)
                        TextField("Phone", text: $newPhone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                }

                Section {
                    Toggle("Add a shipping address", isOn: $includeAddress.animation())
                    if includeAddress {
                        if canUseExistingAddress {
                            Picker("Address", selection: $addressMode) {
                                ForEach(AddressMode.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        if addressMode == .existing, canUseExistingAddress {
                            Picker("Select an address", selection: $selectedAddressId) {
                                Text("Select an address").tag(Int?.none)
                                ForEach(existingAddresses) { address in
                                    Text(address.singleLine).tag(Optional(address.id))
                                }
                            }
                        } else {
                            AddressFormFields(address: $address)
                        }
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

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
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
            .navigationTitle("New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await submit() } }
                        .disabled(!isValid || isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .task { await loadOptions() }
            .onChange(of: selectedCustomerId) { _, newValue in
                Task { await loadCustomerDetail(newValue) }
            }
            .toast($errorMessage)
        }
    }

    private func loadOptions() async {
        customersLoading = true
        productsLoading = true
        async let customersResult = apiClient.get("customers/?page_size=100", as: CursorPage<Customer>.self)
        async let productsResult = apiClient.get("products/?page_size=100", as: CursorPage<Product>.self)
        customerOptions = (try? await customersResult)?.results ?? []
        productOptions = ((try? await productsResult)?.results ?? []).sortedForOrderPicker()
        customersLoading = false
        productsLoading = false

        // Bacteriostatic Water is added to nearly every order, so default
        // the first line item to it (1 unit at catalog price) instead of
        // making staff pick it from the list every time.
        if let defaultProduct = productOptions.first(where: { $0.name == "Bacteriostatic Water" }) {
            items[0].selectedProductId = defaultProduct.id
            items[0].unitPriceText = defaultProduct.defaultOrderUnitPrice
        }
    }

    /// Defaults to the customer's first address so placing an order for a
    /// repeat customer doesn't require re-clicking through "add address" ->
    /// "use existing" -> pick-from-list every time -- mirrors
    /// OrderFormModal.tsx's effect.
    private func loadCustomerDetail(_ id: Int?) async {
        guard let id else {
            selectedCustomerDetail = nil
            return
        }
        selectedCustomerDetail = try? await apiClient.get("customers/\(id)/", as: CustomerDetail.self)
        if let first = selectedCustomerDetail?.addresses.first {
            includeAddress = true
            addressMode = .existing
            selectedAddressId = first.id
        } else {
            addressMode = .new
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let resolvedAddress: AddressInput? = {
            guard includeAddress else { return nil }
            if addressMode == .existing, canUseExistingAddress {
                return existingAddresses.first(where: { $0.id == selectedAddressId })?.asInput
            }
            return address
        }()

        let input = CreateOrderInput(
            customerId: customerMode == .existing ? selectedCustomerId : nil,
            newCustomer: customerMode == .new
                ? NewCustomerInput(firstName: newFirstName, lastName: newLastName, phone: newPhone)
                : nil,
            shippingAddress: resolvedAddress,
            status: status,
            discountPercent: includeDiscount && discountType == .percent ? discountPercent : nil,
            discountAmount: includeDiscount && discountType == .amount ? Double(discountAmountText) : nil,
            notes: notes,
            items: items.map { $0.toCreateInput() }
        )

        do {
            let created = try await viewModel.create(input)
            onCreated?(created)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}

#Preview {
    OrderFormView(viewModel: OrdersViewModel())
}
