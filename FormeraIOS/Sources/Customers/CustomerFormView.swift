import SwiftUI

/// Replaces CustomerFormModal.tsx.
struct CustomerFormView: View {
    var viewModel: CustomersViewModel
    var onCreated: ((CustomerDetail) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var includeAddress = false
    @State private var address = AddressInput.empty
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section {
                    Toggle("Add a shipping address", isOn: $includeAddress.animation())
                }

                if includeAddress {
                    Section("Address") {
                        AddressFormFields(address: $address)
                    }
                }
            }
            .navigationTitle("New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await submit() } }
                        .disabled(firstName.isEmpty || lastName.isEmpty || isSubmitting)
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

        let input = CreateCustomerInput(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            notes: notes,
            address: includeAddress ? address : nil
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
    CustomerFormView(viewModel: CustomersViewModel())
}
