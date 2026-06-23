import Foundation

struct OnlineContentCredentialLookup: Equatable {
    let value: String?
    let isConfigured: Bool
}

struct OnlineContentCredentialStore {
    static let curseForgeAPIKeyConfiguredKey = "OnlineContent.CurseForgeAPIKeyConfigured"

    private let secretStore: SecureSecretStore

    init(secretStore: SecureSecretStore = SecureSecretStore()) {
        self.secretStore = secretStore
    }

    var curseForgeAPIKeyConfigured: Bool {
        UserDefaults.standard.bool(forKey: Self.curseForgeAPIKeyConfiguredKey)
    }

    func saveCurseForgeAPIKey(_ value: String) throws -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try secretStore.delete(.curseForgeAPIKey)
            setCurseForgeAPIKeyConfigured(false)
            return false
        }

        try secretStore.save(trimmed, for: .curseForgeAPIKey)
        setCurseForgeAPIKeyConfigured(true)
        return true
    }

    func curseForgeAPIKey(configured: Bool) -> OnlineContentCredentialLookup {
        guard configured else {
            return OnlineContentCredentialLookup(value: nil, isConfigured: false)
        }

        let value = (try? secretStore.load(.curseForgeAPIKey))?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            setCurseForgeAPIKeyConfigured(false)
            return OnlineContentCredentialLookup(value: nil, isConfigured: false)
        }

        return OnlineContentCredentialLookup(value: value, isConfigured: true)
    }

    private func setCurseForgeAPIKeyConfigured(_ configured: Bool) {
        UserDefaults.standard.set(configured, forKey: Self.curseForgeAPIKeyConfiguredKey)
    }
}
