import SwiftUI

/// Pick a week and download that week's Cash Pickup orders as a PDF (see
/// the API's CashPickupReportView) -- the list used to plan the Saturday
/// pickup route. Any day in the week works; the server snaps it back to
/// that week's Saturday.
struct CashPickupReportView: View {
    var viewModel: OrdersViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()
    @State private var isDownloading = false
    @State private var reportURL: URL?
    @State private var isSharePresented = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Any day in the week", selection: $day, displayedComponents: .date)
                } footer: {
                    Text(formatWeekRange(weekStart: saturday(onOrBefore: day)))
                }

                Section {
                    Button {
                        Task { await download() }
                    } label: {
                        if isDownloading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Download Report", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isDownloading)
                }
            }
            .navigationTitle("Cash Pickups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isSharePresented) {
                if let reportURL {
                    ActivityView(items: [reportURL])
                }
            }
            .toast($errorMessage)
        }
    }

    /// Mirrors the server's week_start_for() -- only used for the label.
    private func saturday(onOrBefore date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // Sunday = 1 ... Saturday = 7
        let daysBack = weekday % 7
        return calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: date)) ?? date
    }

    private func download() async {
        errorMessage = nil
        isDownloading = true
        defer { isDownloading = false }
        do {
            let (data, filename) = try await viewModel.fetchCashPickupReport(weekStart: DRFPlainDate.format(day))
            let name = filename ?? "cash-pickups.pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            reportURL = url
            isSharePresented = true
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}
