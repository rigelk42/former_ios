import SwiftUI

/// Reusable address entry fields -- replaces components/AddressFields.tsx.
/// Used by both the customer form (a saved address) and the order form (a
/// shipping address), which send/receive the identical AddressInput shape.
struct AddressFormFields: View {
    @Binding var address: AddressInput

    var body: some View {
        TextField("Address line 1", text: $address.line1)
            .textContentType(.streetAddressLine1)
        TextField("Address line 2 (optional)", text: $address.line2)
            .textContentType(.streetAddressLine2)
        TextField("City", text: $address.city)
            .textContentType(.addressCity)
        TextField("State", text: $address.state)
            .textContentType(.addressState)
        TextField("Postal code", text: $address.postalCode)
            .textContentType(.postalCode)
            .keyboardType(.numbersAndPunctuation)
        TextField("Country", text: $address.country)
            .textContentType(.countryName)
    }
}

extension AddressInput {
    static var empty: AddressInput {
        AddressInput(line1: "", line2: "", city: "", state: "", postalCode: "", country: "US")
    }
}
