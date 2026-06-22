import Foundation

struct MicrosoftMinecraftAuthClient {
    private let httpClient: MicrosoftAuthHTTPClient

    init(httpClient: MicrosoftAuthHTTPClient = MicrosoftAuthHTTPClient()) {
        self.httpClient = httpClient
    }

    func account(from microsoftToken: MicrosoftTokenResponse) async throws -> MinecraftAccount {
        let xbl = try await authenticateXboxLive(microsoftAccessToken: microsoftToken.accessToken)
        let xsts = try await authorizeXSTS(xboxToken: xbl.token)
        let minecraftToken = try await authenticateMinecraft(userHash: xsts.userHash, xstsToken: xsts.token)
        let profile = try await fetchMinecraftProfile(accessToken: minecraftToken.accessToken)

        return MinecraftAccount(
            id: profile.id,
            name: profile.name,
            accessToken: minecraftToken.accessToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(minecraftToken.expiresIn))
        )
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
