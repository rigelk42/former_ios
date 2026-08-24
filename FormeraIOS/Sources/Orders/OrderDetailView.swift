import SwiftUI

/// Replaces OrderDetailModal.tsx as a pushed screen. Holds its own local
/// `order` copy (seeded from the row that was tapped, same as the web's
/// `liveOrder`) so shipment/price-edit responses update this screen
/// immediately without waiting on the list's own refetch.
struct OrderDetailView: View {
    @State private var order: Order
    var viewModel: OrdersViewModel

    @State private var isEditPresented = false
    @State private var isDeleteConfirming = false
    @State private var errorMessage: String?

    @State private var isDownloadingInvoice = false
    @State private var invoiceURL: URL?
    @State private var isSharePresented = false

    @State private var editingItem: OrderLineItem?
    @State private var editingPriceText = ""
    @State private var isEditingPrice = false

    @Environment(\.dismiss) private var dismiss

    init(order: Order, viewModel: OrdersViewModel) {
        _order = State(initialValue: order)
        self.viewModel = viewModel
    }

    // Matches the backend's _LOCKED_SHIPPING_STATUSES: editing is only
    // allowed while there's no active shipping label, so the order record
    // can't drift from what was actually shipped. "voided" is included
    // since voiding clears the active label.
    private var isEditable: Bool {
        order.shippingStatus == .notShipped || order.shippingStatus == .voided
    }

    var body: some View {
        List {
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                LabeledContent("Customer", value: order.customerName)
                LabeledContent("Status") { StatusBadge(order.status) }
                if let discount = order.discount {
                    LabeledContent("Discount", value: "\(discount)%")
                }
                LabeledContent("Total", value: order.totalAmount.asCurrency)
                LabeledContent("Date", value: order.createdAt.formattedAsDate())
            }

            Section("Shipping address") {
                if let shippingAddress = order.shippingAddress {
                    Text(shippingAddress.line2.isEmpty ? shippingAddress.line1 : "\(shippingAddress.line1), \(shippingAddress.line2)")
                    LabeledContent("City", value: shippingAddress.city)
                    LabeledContent("State", value: shippingAddress.state)
                    LabeledContent("Postal code", value: shippingAddress.postalCode)
                    LabeledContent("Country", value: shippingAddress.country)
                } else {
                    Text("No shipping address on file").foregroundStyle(.secondary)
                }
            }

            Section("Shipping") {
                ShipmentSection(order: $order, viewModel: viewModel)
            }

            Section("Items") {
                ForEach(order.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.productName)
                            Spacer()
                            Text(item.subtotal.asCurrency).foregroundStyle(.secondary)
                        }
                        Text("\(item.quantity) × \(item.unitPrice.asCurrency)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Edit Price") {
                            editingItem = item
                            editingPriceText = item.unitPrice
                            isEditingPrice = true
                        }
                        .tint(.blue)
                    }
                }
            }

            Section {
                Button("Delete Order", role: .destructive) {
                    isDeleteConfirming = true
                }
            }
        }
        .navigationTitle(order.orderNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isDownloadingInvoice {
                    ProgressView()
                } else {
                    Button {
                        Task { await downloadInvoice() }
                    } label: {
                        Label("Get Invoice", systemImage: "square.and.arrow.down")
                    }
                }
            }
            if isEditable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { isEditPresented = true }
                }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            OrderEditView(order: order, viewModel: viewModel) { updated in
                order = updated
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if let invoiceURL {
                ActivityView(items: [invoiceURL])
            }
        }
        .confirmationDialog(
            "Delete this order?",
            isPresented: $isDeleteConfirming,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await performDelete() }
            }
        }
        .alert("Edit Price", isPresented: $isEditingPrice) {
            TextField("Price", text: $editingPriceText)
                .keyboardType(.decimalPad)
            Button("Save") { Task { await saveEditingPrice() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func downloadInvoice() async {
        errorMessage = nil
        isDownloadingInvoice = true
        defer { isDownloadingInvoice = false }
        do {
            let (data, filename) = try await viewModel.fetchInvoice(orderId: order.id)
            let name = filename ?? "invoice-\(order.orderNumber).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            invoiceURL = url
            isSharePresented = true
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func performDelete() async {
        do {
            try await viewModel.delete(order)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func saveEditingPrice() async {
        guard let editingItem, let price = Double(editingPriceText) else { return }
        do {
            order = try await viewModel.updateLineItemPrice(orderId: order.id, itemId: editingItem.id, unitPrice: price)
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
