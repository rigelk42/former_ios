import SwiftUI

/// Reusable address entry fields -- replaces components/AddressFields.tsx.
/// Used by both the customer form (a saved address) and the order form (a
/// shipping address), which send/receive the identical AddressInput shape.
/// Country is fixed to "US" (no field for it) -- this business only ships
/// domestically via ShipStation, so a country picker would just be an extra
/// tap to reach the only option that's ever correct.
struct AddressFormFields: View {
    @Binding var address: AddressInput

    var body: some View {
        TextField("Address line 1", text: $address.line1)
            .textContentType(.streetAddressLine1)
        TextField("Address line 2 (optional)", text: $address.line2)
            .textContentType(.streetAddressLine2)
        TextField("City", text: $address.city)
            .textContentType(.addressCity)

        Picker("State", selection: $address.state) {
            Text("Select a state").tag("")
            ForEach(usStates) { option in
                Text(option.label).tag(option.value)
            }
        }

        TextField("Postal code", text: $address.postalCode)
            .textContentType(.postalCode)
            .keyboardType(.numbersAndPunctuation)
    }
}

extension AddressInput {
    static var empty: AddressInput {
        AddressInput(line1: "", line2: "", city: "", state: "CA", postalCode: "", country: "US")
    }
}
