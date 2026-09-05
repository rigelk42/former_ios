import SwiftUI
import UIKit

/// Replaces ShipmentPanel.tsx. Read-only: labels are now bought (and
/// voided) directly in ShipStation's own UI, not here -- see
/// shipstation.py's module docstring. This just reflects whatever
/// ShipStation's webhook (see ShipStationWebhookView) last reported, with
/// "Refresh Tracking" kept as a fallback for a missed webhook delivery or
/// a void done directly in ShipStation (there's no label_voided webhook
/// event in v2, so that specific case can only be caught by a refresh).
struct ShipmentSection: View {
    @Binding var order: Order
    var viewModel: OrdersViewModel

    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var trackingNumberCopied = false
    @Environment(\.openURL) private var openURL

    /// Order only stores ShipStation's raw serviceCode (e.g.
    /// "usps_priority_mail"), not a friendly name -- ShipStation namespaces
    /// codes as "<carrier>_<service...>", so dropping that leading segment
    /// and title-casing the rest turns it into "Priority Mail" for display.
    private var formattedServiceCode: String {
        let parts = order.serviceCode.split(separator: "_")
        let serviceParts = parts.count > 1 ? parts.dropFirst() : parts[...]
        return serviceParts.map { $0.capitalized }.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusBadge(order.shippingStatus)
            if !order.carrierName.isEmpty {
                Text("\(order.carrierName) — \(formattedServiceCode)").font(.subheadline)
            }
            if !order.trackingNumber.isEmpty {
                // Staff copy this to text customers, so it needs to be a
                // one-tap action rather than relying on long-press text
                // selection -- the checkmark swap is the only feedback
                // that it worked.
                Button {
                    UIPasteboard.general.string = order.trackingNumber
                    trackingNumberCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        trackingNumberCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Tracking: \(order.trackingNumber)").font(.subheadline)
                        Image(systemName: trackingNumberCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            if order.shippingStatus != .notShipped {
                VStack(spacing: 8) {
                    if let url = URL(string: order.labelUrl), !order.labelUrl.isEmpty {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Print Label", systemImage: "printer")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Button {
                        Task { await performRefresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Refresh Tracking", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .toast($errorMessage)
    }

    private func performRefresh() async {
        errorMessage = nil
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            order = try await viewModel.refreshShipment(orderId: order.id)
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
