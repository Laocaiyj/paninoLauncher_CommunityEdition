import AppKit
import Foundation

struct MicrosoftAuthService {
    private let tokenStore: SecureTokenStore
    private let oauthClient: MicrosoftOAuthTokenClient
    private let minecraftClient: MicrosoftMinecraftAuthClient

    init(
        tokenStore: SecureTokenStore = SecureTokenStore(),
        oauthClient: MicrosoftOAuthTokenClient = MicrosoftOAuthTokenClient(),
        minecraftClient: MicrosoftMinecraftAuthClient = MicrosoftMinecraftAuthClient()
    ) {
        self.tokenStore = tokenStore
        self.oauthClient = oauthClient
        self.minecraftClient = minecraftClient
    }

    func hasStoredRefreshToken(accountID: String? = nil) -> Bool {
        (try? tokenStore.loadRefreshToken(accountID: accountID)) != nil
    }

    func startDeviceCode(clientId: String) async throws -> DeviceCodeSession {
        try await oauthClient.startDeviceCode(clientId: clientId)
    }

    func openVerificationURI(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func completeDeviceCodeLogin(clientId: String, session deviceSession: DeviceCodeSession) async throws -> MinecraftAccount {
        let token = try await oauthClient.pollForToken(clientId: clientId, deviceSession: deviceSession)
        return try await finishMinecraftLogin(microsoftToken: token)
    }

    func restoreStoredAccount(clientId: String, accountID: String? = nil) async throws -> MinecraftAccount? {
        let clientId = MicrosoftAuthInput.sanitizeClientID(clientId)
        guard !clientId.isEmpty else {
            throw MicrosoftAuthError.missingClientId
        }
        guard let refreshToken = try tokenStore.loadRefreshToken(accountID: accountID) else {
            return nil
        }

        do {
            let token = try await oauthClient.refreshToken(clientId: clientId, refreshToken: refreshToken)
            return try await finishMinecraftLogin(microsoftToken: token)
        } catch let error as OAuthServiceError {
            if error.invalidatesRefreshToken {
                try? tokenStore.deleteRefreshToken(accountID: accountID)
            }
            throw MicrosoftAuthError.serviceError(error.safeDescription)
        } catch {
            throw error
        }
    }

    func signOut(accountID: String? = nil) throws {
        try tokenStore.deleteRefreshToken(accountID: accountID)
    }

    private func finishMinecraftLogin(microsoftToken: MicrosoftTokenResponse) async throws -> MinecraftAccount {
        let account = try await minecraftClient.account(from: microsoftToken)

        if let refreshToken = microsoftToken.refreshToken, !refreshToken.isEmpty {
            try tokenStore.saveRefreshToken(refreshToken, accountID: account.id)
        }

        return account
    }
}
