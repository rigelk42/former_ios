import SwiftUI
import UIKit

/// Replaces ShipmentPanel.tsx.
struct ShipmentSection: View {
    @Binding var order: Order
    var viewModel: OrdersViewModel

    @State private var showForm = false
    @State private var carriers: [Carrier] = []
    @State private var carriersLoading = false
    @State private var selectedCarrierId: String?
    @State private var selectedServiceCode: String?
    // Pre-filled default for a typical small box -- editable per order,
    // same default as the web's DEFAULT_PACKAGE.
    @State private var weightOz = "12"
    @State private var length = "6"
    @State private var width = "4"
    @State private var height = "4"
    @State private var isSubmitting = false
    @State private var isVoiding = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var isVoidConfirming = false
    @State private var trackingNumberCopied = false
    @Environment(\.openURL) private var openURL

    private var selectedCarrier: Carrier? { carriers.first { $0.carrierId == selectedCarrierId } }
    /// Order only stores ShipStation's raw serviceCode (e.g.
    /// "usps_priority_mail"), not a friendly name -- ShipStation namespaces
    /// codes as "<carrier>_<service...>", so dropping that leading segment
    /// and title-casing the rest turns it into "Priority Mail" for display.
    private var formattedServiceCode: String {
        let parts = order.serviceCode.split(separator: "_")
        let serviceParts = parts.count > 1 ? parts.dropFirst() : parts[...]
        return serviceParts.map { $0.capitalized }.joined(separator: " ")
    }
    private var canCreateShipment: Bool {
        order.shippingStatus == .notShipped || order.shippingStatus == .voided
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if canCreateShipment, showForm {
                createForm
            } else if canCreateShipment {
                Button {
                    showForm = true
                    Task { await loadCarriers() }
                } label: {
                    Text(order.shippingAddress == nil ? "Add shipping address" : "Create Shipment")
                }
                .disabled(order.shippingAddress == nil)
            } else {
                shippedSummary
            }
        }
        .confirmationDialog(
            "Void this shipment?",
            isPresented: $isVoidConfirming,
            titleVisibility: .visible
        ) {
            Button("Void", role: .destructive) {
                Task { await performVoid() }
            }
        } message: {
            Text("This cancels the live label with the carrier and cannot be undone.")
        }
        .toast($errorMessage)
    }

    private var shippedSummary: some View {
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
            VStack(spacing: 8) {
                if let url = URL(string: order.labelUrl), !order.labelUrl.isEmpty {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Print Label", systemImage: "printer")
                            .frame(maxWidth: .infinity)
                    }
                }
                if order.shippingStatus == .voided {
                    Button {
                        showForm = true
                        Task { await loadCarriers() }
                    } label: {
                        Text("Create New Shipment")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(order.shippingAddress == nil)
                } else {
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
                    Button(role: .destructive) {
                        isVoidConfirming = true
                    } label: {
                        Text("Void Shipment")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isVoiding)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var createForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This purchases a real, live label from your ShipStation account — double check the carrier, service, and package details below.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Carrier", selection: $selectedCarrierId) {
                Text(carriersLoading ? "Loading…" : "Select a carrier").tag(String?.none)
                ForEach(carriers) { carrier in
                    Text(carrier.friendlyName).tag(Optional(carrier.carrierId))
                }
            }
            .onChange(of: selectedCarrierId) { _, _ in
                let stillValid = selectedCarrier?.services.contains { $0.serviceCode == selectedServiceCode } ?? false
                if !stillValid { selectedServiceCode = nil }
            }

            Picker("Service", selection: $selectedServiceCode) {
                Text("Select a service").tag(String?.none)
                ForEach(selectedCarrier?.services ?? []) { service in
                    Text(service.name).tag(Optional(service.serviceCode))
                }
            }
            .disabled(selectedCarrier == nil)

            HStack {
                labeledField("Weight (oz)", text: $weightOz)
                labeledField("Length (in)", text: $length)
                labeledField("Width (in)", text: $width)
                labeledField("Height (in)", text: $height)
            }

            HStack {
                Button {
                    Task { await performCreate() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Purchase Label")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCarrierId == nil || selectedServiceCode == nil || isSubmitting)

                Button("Cancel") { showForm = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func loadCarriers() async {
        guard carriers.isEmpty else { return }
        carriersLoading = true
        defer { carriersLoading = false }
        do {
            carriers = try await viewModel.fetchCarriers()
            applyDefaultCarrierAndService()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    /// Defaults new shipments to USPS Priority Mail, the most common service for this shop.
    /// Leaves the picker untouched if USPS isn't in the account's ShipStation carriers.
    private func applyDefaultCarrierAndService() {
        guard selectedCarrierId == nil,
              let usps = carriers.first(where: { $0.friendlyName.localizedCaseInsensitiveContains("usps") })
        else { return }
        selectedCarrierId = usps.carrierId
        let priorityMail = usps.services.first {
            $0.name.localizedCaseInsensitiveContains("priority mail")
                && !$0.name.localizedCaseInsensitiveContains("international")
        }
        selectedServiceCode = priorityMail?.serviceCode
    }

    private func performCreate() async {
        guard let carrierId = selectedCarrierId, let serviceCode = selectedServiceCode,
              let carrier = selectedCarrier else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let input = CreateShipmentInput(
            carrierId: carrierId,
            carrierName: carrier.friendlyName,
            serviceCode: serviceCode,
            weightOz: Double(weightOz) ?? 0,
            length: Double(length) ?? 0,
            width: Double(width) ?? 0,
            height: Double(height) ?? 0
        )
        do {
            order = try await viewModel.createShipment(orderId: order.id, input: input)
            showForm = false
        } catch {
            errorMessage = apiErrorMessage(error)
        }
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

    private func performVoid() async {
        errorMessage = nil
        isVoiding = true
        defer { isVoiding = false }
        do {
            order = try await viewModel.voidShipment(orderId: order.id)
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
