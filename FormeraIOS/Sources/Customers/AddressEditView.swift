import SwiftUI

/// Add a new address to a customer, or edit one of their existing ones --
/// POST/PATCH customers/<id>/addresses/[<address_id>/]. Unlike the
/// customer's own name/phone, an address has no separate detail screen, so
/// this single form covers both create and edit.
struct AddressEditView: View {
    let customerId: Int
    var existingAddress: Address?
    var viewModel: CustomersViewModel
    var onSaved: (Address) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var address: AddressInput
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(
        customerId: Int,
        existingAddress: Address? = nil,
        viewModel: CustomersViewModel,
        onSaved: @escaping (Address) -> Void
    ) {
        self.customerId = customerId
        self.existingAddress = existingAddress
        self.viewModel = viewModel
        self.onSaved = onSaved
        _address = State(initialValue: existingAddress?.asInput ?? .empty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AddressFormFields(address: $address)
                }
            }
            .navigationTitle(existingAddress == nil ? "New Address" : "Edit Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingAddress == nil ? "Add" : "Save") { Task { await submit() } }
                        .disabled(isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .toast($errorMessage)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let saved: Address
            if let existingAddress {
                saved = try await viewModel.updateAddress(customerId: customerId, addressId: existingAddress.id, address)
            } else {
                saved = try await viewModel.createAddress(customerId: customerId, address)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
