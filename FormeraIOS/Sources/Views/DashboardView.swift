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

    // A fixed, explicit palette (rather than letting Charts auto-assign
    // colors via foregroundStyle(by:)) so each product's pie slice and its
    // legend-row dot are guaranteed to match -- cycles if there are more
    // products than colors.
    private static let palette: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .indigo, .mint, .brown]

    private var total: Decimal { items.reduce(Decimal(0)) { $0 + $1.revenueValue } }

    private func color(at index: Int) -> Color {
        Self.palette[index % Self.palette.count]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Chart(Array(items.enumerated()), id: \.element.id) { index, item in
                    SectorMark(
                        angle: .value("Revenue", item.revenueValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(color(at: index))
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 260)
                .padding(.horizontal)
                .overlay {
                    VStack {
                        Text(total.formatted(.currency(code: "USD")))
                            .font(.title2.bold())
                            .foregroundStyle(Color.accentColor)
                        Text("Total sales")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            Circle()
                                .fill(color(at: index))
                                .frame(width: 8, height: 8)
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
