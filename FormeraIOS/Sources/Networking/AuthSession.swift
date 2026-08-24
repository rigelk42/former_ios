import Foundation

/// Coordinates access-token refresh for APIClient. An actor (not a plain
/// struct) so concurrent 401s from several in-flight requests share one
/// refresh call instead of each spending the refresh token themselves --
/// the backend rotates and blacklists it on every use, so a second
/// concurrent refresh would otherwise fail outright.
actor AuthSession {
    static let shared = AuthSession()

    /// Posted (on the main thread) when a refresh attempt fails and tokens
    /// are cleared, so AuthService can drop back to the logged-out state
    /// even though the failure happened on a background request, not on an
    /// explicit login/logout call.
    static let didExpireNotification = Notification.Name("com.formera.ios.sessionExpired")

    private let tokenStore: TokenStore
    private var refreshTask: Task<Bool, Never>?

    init(tokenStore: TokenStore = .shared) {
        self.tokenStore = tokenStore
    }

    @discardableResult
    func refreshAccessToken() async -> Bool {
        if let refreshTask {
            return await refreshTask.value
        }
        let task = Task { await self.performRefresh() }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func performRefresh() async -> Bool {
        guard let refresh = tokenStore.refreshToken else { return false }
        do {
            // Unauthenticated: the refresh token travels in the body, not
            // as a Bearer header, so this can't itself trigger the 401
            // retry path in APIClient.
            let response = try await APIClient(tokenStore: tokenStore).post(
                "auth/refresh/",
                body: RefreshRequest(refresh: refresh),
                as: RefreshResponse.self
            )
            tokenStore.save(access: response.access, refresh: response.refresh)
            return true
        } catch {
            tokenStore.clear()
            await MainActor.run {
                NotificationCenter.default.post(name: Self.didExpireNotification, object: nil)
            }
            return false
        }
    }
}
