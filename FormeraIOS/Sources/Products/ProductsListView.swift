import SwiftUI

/// Replaces ProductsPage.tsx's antd Table + Previous/Next pagination.
struct ProductsListView: View {
    @State private var viewModel = ProductsViewModel()
    @State private var isCreatePresented = false

    var body: some View {
        List {
            ForEach(viewModel.filteredProducts) { product in
                NavigationLink(value: product) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                        HStack(spacing: 8) {
                            Text(product.sku)
                            Text("\u{2022}")
                            Text(product.price.asCurrency)
                            Text("\u{2022}")
                            Text("\(product.stock) in stock")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .task { await viewModel.loadMoreIfNeeded(current: product) }
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
            if viewModel.isLoading && viewModel.products.isEmpty {
                ProgressView()
            } else if viewModel.products.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? "No products yet",
                    systemImage: viewModel.errorMessage == nil ? "cube.box" : "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle("Products")
        .navigationDestination(for: Product.self) { product in
            ProductDetailView(productId: product.id, viewModel: viewModel)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search by name")
        .refreshable { await viewModel.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatePresented = true
                } label: {
                    Label("New Product", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatePresented) {
            ProductFormView(viewModel: viewModel)
        }
        .task { await viewModel.loadInitial() }
    }
}

#Preview {
    NavigationStack { ProductsListView() }
}
