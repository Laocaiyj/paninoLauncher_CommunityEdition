import AppKit
import Foundation

enum MicrosoftAuthError: LocalizedError, Equatable {
    case missingClientId
    case invalidResponse
    case invalidVerificationURI
    case expiredDeviceCode
    case authorizationDeclined
    case minecraftProfileMissing
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "Microsoft client ID is required before signing in."
        case .invalidResponse:
            return "The authentication service returned an invalid response."
        case .invalidVerificationURI:
            return "The authentication service returned an invalid verification URL."
        case .expiredDeviceCode:
            return "The Microsoft sign-in code expired."
        case .authorizationDeclined:
            return "Microsoft sign-in was cancelled or declined."
        case .minecraftProfileMissing:
            return "This Microsoft account does not have a Minecraft Java profile."
        case .serviceError(let message):
            return message
        }
    }
}

struct MicrosoftAuthService {
    private let tokenStore = SecureTokenStore()
    private let httpClient = MicrosoftAuthHTTPClient()

    func hasStoredRefreshToken(accountID: String? = nil) -> Bool {
        (try? tokenStore.loadRefreshToken(accountID: accountID)) != nil
    }

    func startDeviceCode(clientId: String) async throws -> DeviceCodeSession {
        let clientId = MicrosoftAuthInput.sanitizeClientID(clientId)
        guard !clientId.isEmpty else {
            throw MicrosoftAuthError.missingClientId
        }

        let request = try httpClient.formRequest(
            url: MicrosoftAuthEndpoints.deviceCode,
            fields: [
                "client_id": clientId,
                "scope": MicrosoftAuthEndpoints.scope
            ]
        )
        let response: DeviceCodeResponse = try await httpClient.send(request)
        guard let verificationURI = URL(string: response.verificationURI) else {
            throw MicrosoftAuthError.invalidVerificationURI
        }

        return DeviceCodeSession(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURI: verificationURI,
            message: response.message,
            intervalSeconds: response.interval,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    func openVerificationURI(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func completeDeviceCodeLogin(clientId: String, session deviceSession: DeviceCodeSession) async throws -> MinecraftAccount {
        let token = try await pollForMicrosoftToken(clientId: clientId, deviceSession: deviceSession)
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
            let token = try await refreshMicrosoftToken(clientId: clientId, refreshToken: refreshToken)
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
        let xbl = try await authenticateXboxLive(microsoftAccessToken: microsoftToken.accessToken)
        let xsts = try await authorizeXSTS(xboxToken: xbl.token)
        let minecraftToken = try await authenticateMinecraft(userHash: xsts.userHash, xstsToken: xsts.token)
        let profile = try await fetchMinecraftProfile(accessToken: minecraftToken.accessToken)

        if let refreshToken = microsoftToken.refreshToken, !refreshToken.isEmpty {
            try tokenStore.saveRefreshToken(refreshToken, accountID: profile.id)
        }

        return MinecraftAccount(
            id: profile.id,
            name: profile.name,
            accessToken: minecraftToken.accessToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(minecraftToken.expiresIn))
        )
    }

    private func pollForMicrosoftToken(clientId: String, deviceSession: DeviceCodeSession) async throws -> MicrosoftTokenResponse {
        var interval = max(deviceSession.intervalSeconds, 5)

        while Date() < deviceSession.expiresAt {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)

            let request = try httpClient.formRequest(
                url: MicrosoftAuthEndpoints.token,
                fields: [
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "client_id": MicrosoftAuthInput.sanitizeClientID(clientId),
                    "device_code": deviceSession.deviceCode
                ]
            )

            do {
                return try await httpClient.send(request)
            } catch let error as OAuthServiceError {
                switch error.code {
                case "authorization_pending":
                    continue
                case "slow_down":
                    interval += 5
                    continue
                case "authorization_declined":
                    throw MicrosoftAuthError.authorizationDeclined
                case "expired_token":
                    throw MicrosoftAuthError.expiredDeviceCode
                default:
                    throw MicrosoftAuthError.serviceError(error.safeDescription)
                }
            }
        }

        throw MicrosoftAuthError.expiredDeviceCode
    }

    private func refreshMicrosoftToken(clientId: String, refreshToken: String) async throws -> MicrosoftTokenResponse {
        let request = try httpClient.formRequest(
            url: MicrosoftAuthEndpoints.token,
            fields: [
                "grant_type": "refresh_token",
                "client_id": MicrosoftAuthInput.sanitizeClientID(clientId),
                "refresh_token": refreshToken,
                "scope": MicrosoftAuthEndpoints.scope
            ]
        )
        return try await httpClient.send(request)
    }

    private func authenticateXboxLive(microsoftAccessToken: String) async throws -> XboxAuthToken {
        let body = XboxUserAuthRequest(
            properties: XboxUserAuthProperties(
                authMethod: "RPS",
                siteName: "user.auth.xboxlive.com",
                rpsTicket: "d=\(microsoftAccessToken)"
            ),
            relyingParty: "http://auth.xboxlive.com",
            tokenType: "JWT"
        )
        let response: XboxAuthResponse = try await httpClient.send(
            httpClient.jsonRequest(url: MicrosoftAuthEndpoints.xboxUserAuth, body: body)
        )
        return XboxAuthToken(token: response.token, userHash: response.userHash)
    }

    private func authorizeXSTS(xboxToken: String) async throws -> XboxAuthToken {
        let body = XSTSAuthRequest(
            properties: XSTSAuthProperties(sandboxId: "RETAIL", userTokens: [xboxToken]),
            relyingParty: "rp://api.minecraftservices.com/",
            tokenType: "JWT"
        )
        let response: XboxAuthResponse = try await httpClient.send(
            httpClient.jsonRequest(url: MicrosoftAuthEndpoints.xstsAuthorize, body: body)
        )
        return XboxAuthToken(token: response.token, userHash: response.userHash)
    }

    private func authenticateMinecraft(userHash: String, xstsToken: String) async throws -> MinecraftTokenResponse {
        let body = MinecraftLoginRequest(identityToken: "XBL3.0 x=\(userHash);\(xstsToken)")
        return try await httpClient.send(httpClient.jsonRequest(url: MicrosoftAuthEndpoints.minecraftLogin, body: body))
    }

    private func fetchMinecraftProfile(accessToken: String) async throws -> MinecraftProfileResponse {
        var request = URLRequest(url: MicrosoftAuthEndpoints.minecraftProfile)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let profile: MinecraftProfileResponse = try await httpClient.send(request)
        guard !profile.id.isEmpty, !profile.name.isEmpty else {
            throw MicrosoftAuthError.minecraftProfileMissing
        }
        return profile
    }
}
