import SwiftUI

/// The four sections from the web app's Toolbar.tsx navLinks.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case customers
    case orders
    case products

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .customers: "Customers"
        case .orders: "Orders"
        case .products: "Products"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .customers: "person.2"
        case .orders: "list.clipboard"
        case .products: "shippingbox.fill"
        }
    }
}

/// One shared shell, adaptive by horizontal size class: a NavigationSplitView
/// sidebar + detail pane on regular width (iPad, or an iPhone's landscape
/// split in some configurations), collapsing to a TabView + NavigationStack
/// per tab on compact width (iPhone portrait) -- see the migration plan's
/// "Navigation shell" architecture decision for why this is one shell rather
/// than two separate layout codepaths.
struct AppShellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: AppSection? = .dashboard

    var body: some View {
        if horizontalSizeClass == .compact {
            TabView(selection: Binding(get: { selection ?? .dashboard }, set: { selection = $0 })) {
                ForEach(AppSection.allCases) { section in
                    NavigationStack {
                        destination(for: section)
                            .toolbar {
                                ToolbarItem(placement: .principal) { LogoTitleView() }
                                ToolbarItem(placement: .topBarTrailing) { AccountMenu() }
                            }
                    }
                    .tabItem { Label(section.title, systemImage: section.systemImage) }
                    .tag(section)
                }
            }
        } else {
            NavigationSplitView {
                List(AppSection.allCases, selection: $selection) { section in
                    Label(section.title, systemImage: section.systemImage).tag(section)
                }
                .safeAreaInset(edge: .top) {
                    LogoTitleView()
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
            } detail: {
                NavigationStack {
                    destination(for: selection ?? .dashboard)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountMenu() } }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for section: AppSection) -> some View {
        switch section {
        case .dashboard: DashboardView()
        case .customers: CustomersListView()
        case .orders: OrdersListView()
        case .products: ProductsListView()
        }
    }
}

/// Replaces the web Toolbar's logo (which links to /dashboard on every
/// page) as the nav bar's principal item -- shown on every section's root
/// screen in both the tab and split-view layouts.
private struct LogoTitleView: View {
    var body: some View {
        Image("FormeraLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 40)
    }
}

/// Replaces the web Toolbar's avatar dropdown -- the one logout affordance,
/// shared by every section's root screen in both the tab and split-view
/// layouts.
private struct AccountMenu: View {
    @Environment(AuthService.self) private var auth
    @State private var showingAbout = false

    var body: some View {
        Menu {
            Button {
                showingAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
            }
            Button(role: .destructive) {
                Task { await auth.logout() }
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .sheet(isPresented: $showingAbout) { AboutView() }
    }
}

#Preview {
    AppShellView()
        .environment(AuthService())
}
