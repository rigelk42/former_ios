import SwiftUI

/// Replaces CustomerDetailModal.tsx as a pushed screen instead of a modal
/// -- native drill-in navigation rather than a fixed-width dialog.
struct CustomerDetailView: View {
    let customerId: Int
    var viewModel: CustomersViewModel

    @State private var detail: CustomerDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditPresented = false
    @State private var isDeleteCustomerConfirming = false
    @State private var addressPendingDelete: Address?
    @State private var isAddAddressPresented = false
    @State private var addressBeingEdited: Address?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let detail {
                List {
                    Section("Contact") {
                        LabeledContent("Name", value: detail.fullName)
                        if !detail.phone.isEmpty {
                            LabeledContent("Phone", value: detail.phone.formattedAsPhone)
                        }
                    }

                    Section("Notes") {
                        if detail.notes.isEmpty {
                            Text("No notes").foregroundStyle(.secondary)
                        } else {
                            Text(detail.notes)
                        }
                    }

                    Section("Addresses") {
                        if detail.addresses.isEmpty {
                            Text("No saved addresses").foregroundStyle(.secondary)
                        }
                        ForEach(detail.addresses) { address in
                            Button {
                                addressBeingEdited = address
                            } label: {
                                Text(address.singleLine)
                            }
                            .foregroundStyle(.primary)
                            .swipeActions {
                                Button(role: .destructive) {
                                    addressPendingDelete = address
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        Button {
                            isAddAddressPresented = true
                        } label: {
                            Label("Add Address", systemImage: "plus")
                        }
                    }

                    Section("Orders") {
                        if detail.orders.isEmpty {
                            Text("No orders yet").foregroundStyle(.secondary)
                        }
                        ForEach(detail.orders) { order in
                            NavigationLink(value: order) {
                                OrderRow(order: order, showCustomerName: false)
                            }
                        }
                    }

                    Section {
                        Button("Delete Customer", role: .destructive) {
                            isDeleteCustomerConfirming = true
                        }
                    }
                }
                // A fresh OrdersViewModel rather than a shared one -- an
                // edit/delete made here won't be reflected back if the
                // Orders tab happens to already be open elsewhere, but
                // that's an acceptable gap for a customer-scoped order
                // history view rather than the main orders list.
                .navigationDestination(for: Order.self) { OrderDetailView(order: $0, viewModel: OrdersViewModel()) }
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(detail?.fullName ?? "Customer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditPresented = true }
                    .disabled(detail == nil)
            }
        }
        .sheet(isPresented: $isEditPresented) {
            if let detail {
                CustomerEditView(detail: detail, viewModel: viewModel) { updated in
                    self.detail = updated
                }
            }
        }
        .sheet(isPresented: $isAddAddressPresented) {
            AddressEditView(customerId: customerId, viewModel: viewModel) { _ in
                Task { await load() }
            }
        }
        .sheet(item: $addressBeingEdited) { address in
            AddressEditView(customerId: customerId, existingAddress: address, viewModel: viewModel) { _ in
                Task { await load() }
            }
        }
        .confirmationDialog(
            "Delete this customer?",
            isPresented: $isDeleteCustomerConfirming,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await performDeleteCustomer() }
            }
        } message: {
            Text("This archives the customer. Their existing orders are kept.")
        }
        .confirmationDialog(
            "Delete this address?",
            isPresented: Binding(
                get: { addressPendingDelete != nil },
                set: { if !$0 { addressPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let address = addressPendingDelete {
                    Task { await performDeleteAddress(address) }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await viewModel.fetchDetail(customerId)
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func performDeleteCustomer() async {
        guard let customer = detail?.asCustomer else { return }
        do {
            try await viewModel.delete(customer)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func performDeleteAddress(_ address: Address) async {
        do {
            try await viewModel.deleteAddress(customerId: customerId, addressId: address.id)
            await load()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
