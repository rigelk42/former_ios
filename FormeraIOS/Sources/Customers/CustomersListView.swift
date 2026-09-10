import SwiftUI

/// Replaces CustomersPage.tsx's antd Table + Previous/Next pagination with
/// a native infinite-scroll List (see the migration plan's "Pagination UX"
/// decision).
struct CustomersListView: View {
    @State private var viewModel = CustomersViewModel()
    @State private var isCreatePresented = false

    /// e.g. "Customers (1,000)" once totalCount has loaded, plain
    /// "Customers" until then.
    private var navigationTitleText: String {
        guard let totalCount = viewModel.totalCount else { return "Customers" }
        return "Customers (\(totalCount.formatted()))"
    }

    var body: some View {
        List {
            ForEach(viewModel.filteredCustomers) { customer in
                NavigationLink(value: customer) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.fullName)
                        if !customer.phone.isEmpty {
                            Text(customer.phone.formattedAsPhone)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .task { await viewModel.loadMoreIfNeeded(current: customer) }
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
        .listStyle(.insetGrouped)
        .overlay {
            if (viewModel.isLoading && viewModel.customers.isEmpty && viewModel.searchText.isEmpty)
                || (viewModel.isSearching && viewModel.searchResults == nil) {
                ProgressView()
            } else if viewModel.filteredCustomers.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? (viewModel.searchText.isEmpty ? "No customers yet" : "No matching customers"),
                    systemImage: viewModel.errorMessage == nil ? "person.2" : "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationDestination(for: Customer.self) { customer in
            CustomerDetailView(customerId: customer.id, viewModel: viewModel)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search by name")
        .task(id: viewModel.searchText) {
            // Debounced: waits for a pause in typing before hitting the
            // server, rather than firing a request per keystroke. Task
            // cancellation (SwiftUI cancels the previous .task(id:) run
            // when searchText changes again) makes the sleep double as
            // the debounce timer -- a keystroke within 300ms cancels the
            // pending search before it fires.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewModel.performSearch()
        }
        .refreshable { await viewModel.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatePresented = true
                } label: {
                    Label("New Customer", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatePresented) {
            CustomerFormView(viewModel: viewModel)
        }
        .task { await viewModel.loadInitial() }
    }
}

#Preview {
    NavigationStack { CustomersListView() }
}
