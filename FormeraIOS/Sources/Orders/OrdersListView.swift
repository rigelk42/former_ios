import SwiftUI

/// Replaces OrdersPage.tsx's synthetic "week header row" hack with a
/// native List Section per week -- see the migration plan's §6.
struct OrdersListView: View {
    @State private var viewModel = OrdersViewModel()
    @State private var isCreatePresented = false

    var body: some View {
        List {
            ForEach(viewModel.weeks) { week in
                Section {
                    ForEach(week.orders) { order in
                        NavigationLink(value: order) {
                            OrderRow(order: order)
                        }
                        .task { await viewModel.loadMoreIfNeeded(current: order) }
                    }
                } header: {
                    HStack {
                        Text(weekLabel(week))
                        Spacer()
                        Text("Total: \(weekTotal(week))")
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.isLoading && viewModel.weeks.isEmpty {
                ProgressView()
            } else if viewModel.weeks.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? "No orders yet",
                    systemImage: viewModel.errorMessage == nil ? "list.clipboard" : "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle("Orders")
        .navigationDestination(for: Order.self) { order in
            OrderDetailView(order: order, viewModel: viewModel)
        }
        .refreshable { await viewModel.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatePresented = true
                } label: {
                    Label("New Order", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatePresented) {
            OrderFormView(viewModel: viewModel)
        }
        .task { await viewModel.loadInitial() }
    }

    private func weekLabel(_ week: OrderWeekGroup) -> String {
        guard let date = week.weekStart.asLocalMidnight else { return week.weekStart }
        return formatWeekRange(weekStart: date)
    }

    private func weekTotal(_ week: OrderWeekGroup) -> String {
        let total = week.orders.reduce(Decimal(0)) { $0 + (Decimal(string: $1.totalAmount) ?? 0) }
        return total.formatted(.currency(code: "USD"))
    }
}

#Preview {
    NavigationStack { OrdersListView() }
}
