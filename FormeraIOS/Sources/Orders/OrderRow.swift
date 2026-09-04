import SwiftUI

/// One order's summary line -- reused by OrdersListView (where the
/// customer name matters, since it's a cross-customer list) and
/// CustomerDetailView's order history (where it doesn't, since every row
/// is already that one customer's order).
struct OrderRow: View {
    let order: Order
    var showCustomerName = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    if showCustomerName {
                        Text(order.customerName)
                    }
                    Text(order.orderDate.formattedAsPlainDate())
                        .font(showCustomerName ? .caption : .body)
                        .foregroundStyle(showCustomerName ? .secondary : .primary)
                    StatusBadge(order.status)
                }
                Spacer()
                Text(order.totalAmount.asCurrency)
                    .font(.body.monospacedDigit())
            }
            // Full-width row of its own (not squeezed into the leading
            // VStack above) so a long note isn't cramped next to the
            // trailing total -- omitted entirely rather than shown as
            // "No notes" (unlike OrderDetailView's dedicated section),
            // since most rows in a scrolling list won't have one.
            if !order.notes.isEmpty {
                Text(order.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
