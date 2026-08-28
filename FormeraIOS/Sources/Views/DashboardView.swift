import Charts
import SwiftUI

/// Replaces the old placeholder heading (see git history) now that the
/// backend has a real aggregation endpoint -- a pie chart of sales per
/// item for a selectable date range, defaulting to the current month.
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                DatePicker(
                    "From",
                    selection: $viewModel.startDate,
                    in: ...viewModel.endDate,
                    displayedComponents: .date
                )
                DatePicker(
                    "To",
                    selection: $viewModel.endDate,
                    in: viewModel.startDate...Date(),
                    displayedComponents: .date
                )
            }
            .padding(.horizontal)

            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        viewModel.errorMessage ?? "No sales in this range",
                        systemImage: viewModel.errorMessage == nil ? "chart.pie" : "exclamationmark.triangle"
                    )
                } else {
                    SalesPieChart(items: viewModel.items)
                }
            }
        }
        .navigationTitle("Dashboard")
        .task { await viewModel.load() }
        .onChange(of: viewModel.startDate) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.endDate) { _, _ in Task { await viewModel.load() } }
    }
}

private struct SalesPieChart: View {
    let items: [SalesSummaryItem]

    private var total: Decimal { items.reduce(Decimal(0)) { $0 + $1.revenueValue } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Chart(items) { item in
                    SectorMark(
                        angle: .value("Revenue", item.revenueValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Product", item.productName))
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 260)
                .padding(.horizontal)
                .overlay {
                    VStack {
                        Text(total.formatted(.currency(code: "USD")))
                            .font(.title2.bold())
                        Text("Total sales")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(items) { item in
                        HStack {
                            Text(item.productName)
                            Spacer()
                            Text("\(item.quantity)x")
                                .foregroundStyle(.secondary)
                            Text(percentage(of: item))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, alignment: .trailing)
                            Text(item.revenueValue.formatted(.currency(code: "USD")))
                                .fontWeight(.medium)
                                .frame(minWidth: 68, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    /// This item's share of the filtered range's total revenue, e.g.
    /// "34.7%" -- "--" when the range's total is zero (every item free/
    /// zero-priced) rather than dividing by zero.
    private func percentage(of item: SalesSummaryItem) -> String {
        guard total > 0 else { return "--" }
        let fraction = Double(truncating: (item.revenueValue / total) as NSDecimalNumber)
        return fraction.formatted(.percent.precision(.fractionLength(1)))
    }
}

#Preview {
    NavigationStack { DashboardView() }
}
