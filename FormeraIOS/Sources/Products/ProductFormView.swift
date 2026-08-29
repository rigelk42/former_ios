import SwiftUI

/// Replaces ProductFormModal.tsx, including its dynamic ingredients
/// (dosages) sub-form.
struct ProductFormView: View {
    var viewModel: ProductsViewModel
    var onCreated: ((ProductDetail) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sku = ""
    @State private var description = ""
    @State private var price = ""
    @State private var stock = 0
    @State private var dosages: [DosageInput] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("SKU", text: $sku)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper("Stock: \(stock)", value: $stock, in: 0...100_000)
                }

                Section("Ingredients") {
                    ForEach($dosages) { $dosage in
                        HStack {
                            TextField("Ingredient name", text: $dosage.ingredientName)
                            TextField("mg", text: $dosage.amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                        }
                    }
                    .onDelete { dosages.remove(atOffsets: $0) }

                    Button {
                        dosages.append(DosageInput(ingredientName: "", amount: "", unit: .mg))
                    } label: {
                        Label("Add ingredient", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await submit() } }
                        .disabled(name.isEmpty || sku.isEmpty || price.isEmpty || isSubmitting)
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

        // Mirrors the web's values.price.toFixed(2) / amount.toFixed(3) --
        // the backend expects DecimalField-compatible strings, not
        // arbitrary user-typed precision.
        let formattedPrice = String(format: "%.2f", Double(price) ?? 0)
        let formattedDosages = dosages.map { dosage in
            DosageInput(
                ingredientName: dosage.ingredientName,
                amount: String(format: "%.3f", Double(dosage.amount) ?? 0),
                unit: .mg
            )
        }

        let input = CreateProductInput(
            name: name,
            description: description,
            sku: sku,
            price: formattedPrice,
            stock: stock,
            dosages: formattedDosages
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
    ProductFormView(viewModel: ProductsViewModel())
}
