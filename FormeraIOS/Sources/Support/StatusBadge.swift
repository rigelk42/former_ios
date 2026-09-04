import SwiftUI

/// Small colored capsule -- replaces the web's antd <Tag> statusColor /
/// shippingStatusColor lookups (OrdersPage.tsx, ShipmentPanel.tsx).
struct StatusBadge: View {
    let text: String
    let color: Color

    init(_ status: OrderStatus) {
        text = status.label
        switch status {
        case .paid: color = .blue
        case .cashPickup: color = .green
        case .standby: color = .orange
        case .venmo: color = .cyan
        case .referral: color = .purple
        }
    }

    init(_ status: ShippingStatus) {
        text = status.label
        switch status {
        case .notShipped: color = .gray
        case .labelCreated: color = .blue
        case .inTransit: color = .indigo
        case .delivered: color = .green
        case .exception: color = .red
        case .voided: color = .gray
        }
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
