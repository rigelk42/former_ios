import SwiftUI

/// Replaces CustomerFormModal.tsx.
struct CustomerFormView: View {
    var viewModel: CustomersViewModel
    var onCreated: ((CustomerDetail) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var includeAddress = false
    @State private var address = AddressInput.empty
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section("Contact") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
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
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let input = CreateCustomerInput(
            firstName: firstName,
            lastName: lastName,
            email: email.isEmpty ? nil : email,
            phone: phone,
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
