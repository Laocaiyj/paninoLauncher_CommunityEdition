import Foundation
import Security

enum SecureSecretKey: String, Sendable {
    case curseForgeAPIKey = "curseforge-api-key"
}

enum SecureSecretStoreError: LocalizedError, Equatable {
    case encodingFailed
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode the secret for secure storage."
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        }
    }
}

struct SecureSecretStore: Equatable, Sendable {
    private let service = "dev.panino.launcher.secrets"

    func load(_ key: SecureSecretKey) throws -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SecureSecretStoreError.unexpectedStatus(status)
        }

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String, for key: SecureSecretKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureSecretStoreError.encodingFailed
        }

        try delete(key)

        var item = baseQuery(key)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureSecretStoreError.unexpectedStatus(status)
        }
    }

    func delete(_ key: SecureSecretKey) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureSecretStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(_ key: SecureSecretKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
