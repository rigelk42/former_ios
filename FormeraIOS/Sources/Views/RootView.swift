import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        switch auth.status {
        case .checking:
            ProgressView()
        case .unauthenticated:
            LoginView()
        case .authenticated:
            AppShellView()
        }
    }
}

#Preview {
    RootView()
        .environment(AuthService())
}
