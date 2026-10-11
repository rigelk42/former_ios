import Charts
import SwiftUI

/// Replaces the old placeholder heading (see git history) now that the
/// backend has a real aggregation endpoint -- a pie chart of units sold per
/// item for a selectable date range, defaulting to the current month.
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WeeklySalesChart(weeks: viewModel.weeklySales, errorMessage: viewModel.weeklyErrorMessage)
                    .dashboardCard()

                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Units Sold by Product")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)

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

                    Group {
                        if viewModel.isLoading && viewModel.items.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if viewModel.items.isEmpty {
                            ContentUnavailableView(
                                viewModel.errorMessage ?? "No sales in this range",
                                systemImage: viewModel.errorMessage == nil ? "chart.pie" : "exclamationmark.triangle"
                            )
                            .frame(minHeight: 200)
                        } else {
                            SalesPieChart(items: viewModel.items)
                        }
                    }
                }
                .dashboardCard()
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .task { await viewModel.load() }
        .task { await viewModel.loadWeekly() }
        .onChange(of: viewModel.startDate) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.endDate) { _, _ in Task { await viewModel.load() } }
    }
}

private extension View {
    /// Each dashboard chart sits in its own rounded card on the grouped
    /// background, so the two read as clearly separate sections.
    func dashboardCard() -> some View {
        padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }
}

private struct SalesPieChart: View {
    let items: [SalesSummaryItem]

    // A fixed, explicit palette (rather than letting Charts auto-assign
    // colors via foregroundStyle(by:)) so each product's pie slice and its
    // legend-row dot are guaranteed to match -- cycles if there are more
    // products than colors.
    private static let palette: [Color] = [
        .blue, .green, .orange, .purple, .red, .cyan, .yellow, .indigo, .mint, .brown
    ]

    private var totalUnits: Int { items.reduce(0) { $0 + $1.quantity } }

    private func color(at index: Int) -> Color {
        Self.palette[index % Self.palette.count]
    }

    var body: some View {
        VStack(spacing: 16) {
                Chart(Array(items.enumerated()), id: \.element.id) { index, item in
                    SectorMark(
                        angle: .value("Units sold", item.quantity),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(color(at: index))
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 260)
                .overlay {
                    VStack {
                        Text("\(totalUnits)")
                            .font(.title2.bold())
                            .foregroundStyle(Color.accentColor)
                        Text("Units sold")
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
                                .fontWeight(.medium)
                                .frame(minWidth: 52, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
        }
    }

    /// This item's share of the filtered range's units sold, e.g. "34.7%"
    /// -- "--" when no units were sold rather than dividing by zero.
    private func percentage(of item: SalesSummaryItem) -> String {
        guard totalUnits > 0 else { return "--" }
        let fraction = Double(item.quantity) / Double(totalUnits)
        return fraction.formatted(.percent.precision(.fractionLength(1)))
    }
}

/// Money sold in each of the last 10 Saturday-Friday weeks (independent of
/// the date range above), as horizontal bars with the newest week on top.
private struct WeeklySalesChart: View {
    let weeks: [WeeklySalesItem]
    let errorMessage: String?

    /// Percent change vs. the previous week, or nil for the oldest week and
    /// whenever the previous week had no sales (nothing to compare against)
    /// or the total didn't change.
    private func weekOverWeekChange(of week: WeeklySalesItem) -> Double? {
        guard let index = weeks.firstIndex(of: week), index > 0 else { return nil }
        let previous = weeks[index - 1].totalValue
        guard previous > 0 else { return nil }
        let change = Double(truncating: ((week.totalValue - previous) / previous * 100) as NSDecimalNumber)
        return change == 0 ? nil : change
    }

    // The week labels sit outside the bars' plot area, so the plot is inset
    // by the widest one -- measured with the text style the chart renders
    // it in, so it follows Dynamic Type and the data -- and the bars share
    // whatever width is left. The amount + change annotations on the right
    // need no such inset: Charts already shrinks the plot to fit the widest.
    private var labelColumnWidth: CGFloat {
        widest(weeks.map(\.weekStartLabel)) + 12
    }

    private func percentText(_ change: Double) -> String {
        abs(change).formatted(.number.precision(.fractionLength(0...1)))
    }

    private func widest(_ strings: [String]) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .caption1)
        return strings
            .map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) }
            .max() ?? 0
    }

    /// "(↑ 12.3%)" in green for an increase, "(↓ 4.5%)" in red for a decline.
    private func changeLabel(_ change: Double) -> some View {
        let color: Color = change > 0 ? .green : .red
        return Text("(\(Image(systemName: change > 0 ? "arrow.up" : "arrow.down")) \(percentText(change))%)")
            .foregroundStyle(color)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Last 10 Weeks of Sales")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if weeks.isEmpty {
                ContentUnavailableView(
                    errorMessage ?? "No weekly sales yet",
                    systemImage: errorMessage == nil ? "chart.bar" : "exclamationmark.triangle"
                )
                .frame(minHeight: 200)
            } else {
                Chart(weeks.reversed()) { week in
                    BarMark(
                        x: .value("Sales", week.totalValue),
                        y: .value("Week of", week.weekStartLabel)
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .center) {
                        HStack(spacing: 4) {
                            Text(week.totalValue.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                                .foregroundStyle(.secondary)
                            if let change = weekOverWeekChange(of: week) {
                                changeLabel(change)
                            }
                        }
                        .font(.caption)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel(centered: true)
                    }
                }
                .chartPlotStyle { plot in
                    plot.padding(.leading, labelColumnWidth)
                }
                .chartYScale(domain: weeks.reversed().map(\.weekStartLabel))
                .frame(height: CGFloat(weeks.count) * 30)
            }
        }
    }
}

#Preview {
    NavigationStack { DashboardView() }
}
