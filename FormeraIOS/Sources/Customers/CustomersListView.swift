import SwiftUI

/// Replaces CustomersPage.tsx's antd Table + Previous/Next pagination with
/// a native infinite-scroll List (see the migration plan's "Pagination UX"
/// decision).
struct CustomersListView: View {
    @State private var viewModel = CustomersViewModel()
    @State private var isCreatePresented = false

    var body: some View {
        List {
            ForEach(viewModel.filteredCustomers) { customer in
                NavigationLink(value: customer) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.fullName)
                        if let email = customer.email, !email.isEmpty {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !customer.phone.isEmpty {
                            Text(customer.phone)
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
        .listStyle(.plain)
        .overlay {
            if viewModel.isLoading && viewModel.customers.isEmpty {
                ProgressView()
            } else if viewModel.customers.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? "No customers yet",
                    systemImage: viewModel.errorMessage == nil ? "person.2" : "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle("Customers")
        .navigationDestination(for: Customer.self) { customer in
            CustomerDetailView(customerId: customer.id, viewModel: viewModel)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search by name")
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
