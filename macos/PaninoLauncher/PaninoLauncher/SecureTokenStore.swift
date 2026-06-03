import Foundation
import Security

enum SecureTokenStoreError: LocalizedError, Equatable {
    case encodingFailed
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode the token for secure storage."
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        }
    }
}

struct SecureTokenStore: Equatable {
    private let service = "dev.panino.launcher.microsoft"
    private let defaultAccount = "refresh-token"

    func loadRefreshToken(accountID: String? = nil) throws -> String? {
        var query = baseQuery(accountID: accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SecureTokenStoreError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func saveRefreshToken(_ token: String, accountID: String? = nil) throws {
        guard let data = token.data(using: .utf8) else {
            throw SecureTokenStoreError.encodingFailed
        }

        try deleteRefreshToken(accountID: accountID)

        var item = baseQuery(accountID: accountID)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureTokenStoreError.unexpectedStatus(status)
        }
    }

    func deleteRefreshToken(accountID: String? = nil) throws {
        let status = SecItemDelete(baseQuery(accountID: accountID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureTokenStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(accountID: String? = nil) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keychainAccount(accountID: accountID)
        ]
    }

    private func keychainAccount(accountID: String?) -> String {
        guard let accountID, !accountID.isEmpty else {
            return defaultAccount
        }
        return "refresh-token-\(accountID)"
    }
}
