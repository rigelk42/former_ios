import SwiftUI

/// Replaces CustomerEditModal.tsx.
struct CustomerEditView: View {
    let detail: CustomerDetail
    var viewModel: CustomersViewModel
    var onUpdated: (CustomerDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var notes: String
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
        _phone = State(initialValue: detail.phone)
        _notes = State(initialValue: detail.notes)
    }

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
            .toast($errorMessage)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let input = UpdateCustomerInput(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            notes: notes
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
