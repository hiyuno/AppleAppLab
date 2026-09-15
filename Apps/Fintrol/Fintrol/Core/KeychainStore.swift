import Foundation
import Security

/// The only credential in this project: the user's personal Banxico SIE token
/// (SECURITY.md C-12). `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — explicitly no
/// `kSecAttrSynchronizable` (no iCloud Keychain sync) and no `keychain-access-groups`
/// entitlement (this is the app's own default keychain item, never shared with anything).
public enum KeychainError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
}

public enum KeychainStore {
    private static let service = "mx.9866.fintrol.banxico"
    private static let account = "bmx-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Saves (or replaces) the token. Updates the existing item in place — never
    /// delete-then-add, so a failed save can't leave the user with no token at all.
    public static func save(_ value: String) throws {
        let data = Data(value.utf8)
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
            return
        }
        guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
    }

    public static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
