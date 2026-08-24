import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        switch auth.status {
        case .checking:
            ProgressView()
        case .unauthenticated:
            LoginView()
        case .authenticated(let user):
            HomeView(user: user)
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    let user: User

    var body: some View {
        VStack(spacing: 16) {
            Text("Formera")
                .font(.largeTitle.bold())

            Text("Signed in as \(user.email)")
                .foregroundStyle(.secondary)

            Button("Log Out") {
                Task { await auth.logout() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
