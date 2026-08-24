import Foundation

@MainActor
final class AuthService: ObservableObject {
    enum Status: Equatable {
        /// Initial state while `bootstrap()` checks for a stored session.
        case checking
        case unauthenticated
        case authenticated(User)
    }

    @Published private(set) var status: Status = .checking

    private let apiClient: APIClient
    private let tokenStore: TokenStore
    private var sessionExpiredObserver: NSObjectProtocol?

    init(apiClient: APIClient = APIClient(), tokenStore: TokenStore = .shared) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore

        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: AuthSession.didExpireNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.status = .unauthenticated }
        }
    }

    deinit {
        if let sessionExpiredObserver {
            NotificationCenter.default.removeObserver(sessionExpiredObserver)
        }
    }

    /// Call once at launch: restores a session from a stored token, if any.
    func bootstrap() async {
        guard tokenStore.accessToken != nil else {
            status = .unauthenticated
            return
        }
        do {
            let user = try await apiClient.get("auth/me/", as: User.self)
            status = .authenticated(user)
        } catch {
            tokenStore.clear()
            status = .unauthenticated
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await apiClient.post(
            "auth/login/",
            body: LoginRequest(email: email, password: password),
            as: LoginResponse.self
        )
        tokenStore.save(access: response.access, refresh: response.refresh)
        status = .authenticated(response.user)
    }

    func logout() async {
        if let refresh = tokenStore.refreshToken {
            // Best-effort: whether or not the server-side revoke succeeds,
            // the app must still drop its local session.
            try? await apiClient.post("auth/logout/", body: RefreshRequest(refresh: refresh))
        }
        tokenStore.clear()
        status = .unauthenticated
    }
}
