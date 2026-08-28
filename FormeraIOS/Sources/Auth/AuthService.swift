import Foundation
import Observation

@MainActor
@Observable
final class AuthService {
    enum Status: Equatable {
        /// Initial state while `bootstrap()` checks for a stored session.
        case checking
        case unauthenticated
        case authenticated(User)
    }

    private(set) var status: Status = .checking

    private let apiClient: APIClient
    private let tokenStore: TokenStore
    // Not observable state (nothing reads it for rendering), and deinit
    // runs nonisolated regardless of the class's own @MainActor isolation
    // (deallocation isn't tied to any actor) -- @ObservationIgnored is
    // needed for nonisolated(unsafe) to apply at all, since @Observable
    // otherwise wraps every stored property in tracking machinery that
    // rejects a nonisolated mutable property outright.
    @ObservationIgnored
    nonisolated(unsafe) private var sessionExpiredObserver: NSObjectProtocol?

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
            authenticated: false,
            as: LoginResponse.self
        )
        tokenStore.save(access: response.access, refresh: response.refresh)
        status = .authenticated(response.user)
    }

    func logout() async {
        if let refresh = tokenStore.refreshToken {
            // Best-effort: whether or not the server-side revoke succeeds,
            // the app must still drop its local session.
            _ = try? await apiClient.post("auth/logout/", body: RefreshRequest(refresh: refresh), authenticated: false)
        }
        tokenStore.clear()
        status = .unauthenticated
    }
}
