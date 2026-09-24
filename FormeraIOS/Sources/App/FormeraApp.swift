import SwiftUI

@main
struct FormeraApp: App {
    @UIApplicationDelegateAdaptor(NotificationPresenter.self) private var notificationPresenter
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .task { await auth.bootstrap() }
        }
    }
}
