import Foundation
import Security

/// Persists the JWT access/refresh token pair in the Keychain (not
/// UserDefaults) since they're long-lived credentials. Scoped with
/// kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly so tokens survive a
/// device restart without unlocking but never sync to iCloud Keychain.
struct TokenStore {
    static let shared = TokenStore()

    private let service = "com.formera.ios.tokens"
    private let accessAccount = "access"
    private let refreshAccount = "refresh"

    var accessToken: String? { read(account: accessAccount) }
    var refreshToken: String? { read(account: refreshAccount) }

    func save(access: String, refresh: String) {
        write(access, account: accessAccount)
        write(refresh, account: refreshAccount)
    }

    func clear() {
        delete(account: accessAccount)
        delete(account: refreshAccount)
    }

    private func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(newItem as CFDictionary, nil)
    }

    private func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
