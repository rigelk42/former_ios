import SwiftUI

/// Replaces CustomerEditModal.tsx.
struct CustomerEditView: View {
    let detail: CustomerDetail
    var viewModel: CustomersViewModel
    var onUpdated: (CustomerDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phone: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(
        detail: CustomerDetail,
        viewModel: CustomersViewModel,
        onUpdated: @escaping (CustomerDetail) -> Void
    ) {
        self.detail = detail
        self.viewModel = viewModel
        self.onUpdated = onUpdated
        _firstName = State(initialValue: detail.firstName)
        _lastName = State(initialValue: detail.lastName)
        _email = State(initialValue: detail.email ?? "")
        _phone = State(initialValue: detail.phone)
    }

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
            }
            .navigationTitle("Edit Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await submit() } }
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

        let input = UpdateCustomerInput(
            firstName: firstName,
            lastName: lastName,
            email: email.isEmpty ? nil : email,
            phone: phone
        )
        do {
            let updated = try await viewModel.update(detail.id, input)
            onUpdated(updated)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
