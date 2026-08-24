import SwiftUI

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
    @Environment(\.openURL) private var openURL

    private var selectedCarrier: Carrier? { carriers.first { $0.carrierId == selectedCarrierId } }
    private var canCreateShipment: Bool {
        order.shippingStatus == .notShipped || order.shippingStatus == .voided
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }

            if canCreateShipment, showForm {
                createForm
            } else if canCreateShipment {
                Button {
                    showForm = true
                } label: {
                    Text(order.shippingAddress == nil ? "Add shipping address" : "Create Shipment")
                }
                .disabled(order.shippingAddress == nil)
                .task { await loadCarriers() }
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
    }

    private var shippedSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusBadge(order.shippingStatus)
            if !order.carrierName.isEmpty {
                Text("\(order.carrierName) — \(order.serviceCode)").font(.subheadline)
            }
            if !order.trackingNumber.isEmpty {
                Text("Tracking: \(order.trackingNumber)").font(.subheadline)
            }
            HStack {
                if let url = URL(string: order.labelUrl), !order.labelUrl.isEmpty {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Print Label", systemImage: "printer")
                    }
                }
                if order.shippingStatus == .voided {
                    Button("Create New Shipment") {
                        showForm = true
                    }
                    .disabled(order.shippingAddress == nil)
                    .task { await loadCarriers() }
                } else {
                    Button {
                        Task { await performRefresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Label("Refresh Tracking", systemImage: "arrow.clockwise")
                        }
                    }
                    Button("Void Shipment", role: .destructive) {
                        isVoidConfirming = true
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
            .onChange(of: selectedCarrierId) { _, _ in selectedServiceCode = nil }

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
        } catch {
            errorMessage = apiErrorMessage(error)
        }
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
