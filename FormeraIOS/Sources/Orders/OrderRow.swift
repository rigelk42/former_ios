import SwiftUI

/// One order's summary line -- reused by OrdersListView (where the
/// customer name matters, since it's a cross-customer list) and
/// CustomerDetailView's order history (where it doesn't, since every row
/// is already that one customer's order).
struct OrderRow: View {
    let order: Order
    var showCustomerName = true

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if showCustomerName {
                    Text(order.customerName)
                }
                Text(order.createdAt.formattedAsDate())
                    .font(showCustomerName ? .caption : .body)
                    .foregroundStyle(showCustomerName ? .secondary : .primary)
                StatusBadge(order.status)
            }
            Spacer()
            Text(order.totalAmount.asCurrency)
                .font(.body.monospacedDigit())
        }
        .padding(.vertical, 2)
    }
}
