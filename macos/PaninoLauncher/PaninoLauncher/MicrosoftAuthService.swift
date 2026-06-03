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
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 90
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: configuration)
    }

    func hasStoredRefreshToken(accountID: String? = nil) -> Bool {
        (try? tokenStore.loadRefreshToken(accountID: accountID)) != nil
    }

    func startDeviceCode(clientId: String) async throws -> DeviceCodeSession {
        let clientId = sanitizeClientId(clientId)
        guard !clientId.isEmpty else {
            throw MicrosoftAuthError.missingClientId
        }

        let request = try formRequest(
            url: MicrosoftAuthEndpoints.deviceCode,
            fields: [
                "client_id": clientId,
                "scope": MicrosoftAuthEndpoints.scope
            ]
        )
        let response: DeviceCodeResponse = try await send(request)
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
        let clientId = sanitizeClientId(clientId)
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

            let request = try formRequest(
                url: MicrosoftAuthEndpoints.token,
                fields: [
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "client_id": sanitizeClientId(clientId),
                    "device_code": deviceSession.deviceCode
                ]
            )

            do {
                return try await send(request)
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
        let request = try formRequest(
            url: MicrosoftAuthEndpoints.token,
            fields: [
                "grant_type": "refresh_token",
                "client_id": sanitizeClientId(clientId),
                "refresh_token": refreshToken,
                "scope": MicrosoftAuthEndpoints.scope
            ]
        )
        return try await send(request)
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
        let response: XboxAuthResponse = try await send(
            jsonRequest(url: MicrosoftAuthEndpoints.xboxUserAuth, body: body)
        )
        return XboxAuthToken(token: response.token, userHash: response.userHash)
    }

    private func authorizeXSTS(xboxToken: String) async throws -> XboxAuthToken {
        let body = XSTSAuthRequest(
            properties: XSTSAuthProperties(sandboxId: "RETAIL", userTokens: [xboxToken]),
            relyingParty: "rp://api.minecraftservices.com/",
            tokenType: "JWT"
        )
        let response: XboxAuthResponse = try await send(
            jsonRequest(url: MicrosoftAuthEndpoints.xstsAuthorize, body: body)
        )
        return XboxAuthToken(token: response.token, userHash: response.userHash)
    }

    private func authenticateMinecraft(userHash: String, xstsToken: String) async throws -> MinecraftTokenResponse {
        let body = MinecraftLoginRequest(identityToken: "XBL3.0 x=\(userHash);\(xstsToken)")
        return try await send(jsonRequest(url: MicrosoftAuthEndpoints.minecraftLogin, body: body))
    }

    private func fetchMinecraftProfile(accessToken: String) async throws -> MinecraftProfileResponse {
        var request = URLRequest(url: MicrosoftAuthEndpoints.minecraftProfile)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let profile: MinecraftProfileResponse = try await send(request)
        guard !profile.id.isEmpty, !profile.name.isEmpty else {
            throw MicrosoftAuthError.minecraftProfileMissing
        }
        return profile
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MicrosoftAuthError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                throw OAuthServiceError(response: oauthError)
            }
            if let minecraftError = try? JSONDecoder().decode(MinecraftErrorResponse.self, from: data) {
                throw MicrosoftAuthError.serviceError(minecraftError.safeDescription)
            }
            throw MicrosoftAuthError.serviceError("Authentication service returned HTTP \(httpResponse.statusCode).")
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func formRequest(url: URL, fields: [String: String]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded(fields).data(using: .utf8)
        return request
    }

    private func jsonRequest<Body: Encodable>(url: URL, body: Body) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func formEncoded(_ fields: [String: String]) -> String {
        fields
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .sorted()
            .joined(separator: "&")
    }

    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func sanitizeClientId(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum MicrosoftAuthEndpoints {
    static let scope = "XboxLive.signin offline_access"
    static let deviceCode = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
    static let token = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
    static let xboxUserAuth = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
    static let xstsAuthorize = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
    static let minecraftLogin = URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!
    static let minecraftProfile = URL(string: "https://api.minecraftservices.com/minecraft/profile")!
}

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let expiresIn: Int
    let interval: Int
    let message: String

    private enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
        case message
    }
}

private struct MicrosoftTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private struct OAuthServiceError: Error {
    let code: String
    let safeDescription: String

    var invalidatesRefreshToken: Bool {
        code == "invalid_grant" || code == "interaction_required"
    }

    init(response: OAuthErrorResponse) {
        code = response.error
        safeDescription = response.errorDescription ?? response.error
    }
}

private struct XboxUserAuthRequest: Encodable {
    let properties: XboxUserAuthProperties
    let relyingParty: String
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case properties = "Properties"
        case relyingParty = "RelyingParty"
        case tokenType = "TokenType"
    }
}

private struct XboxUserAuthProperties: Encodable {
    let authMethod: String
    let siteName: String
    let rpsTicket: String

    private enum CodingKeys: String, CodingKey {
        case authMethod = "AuthMethod"
        case siteName = "SiteName"
        case rpsTicket = "RpsTicket"
    }
}

private struct XSTSAuthRequest: Encodable {
    let properties: XSTSAuthProperties
    let relyingParty: String
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case properties = "Properties"
        case relyingParty = "RelyingParty"
        case tokenType = "TokenType"
    }
}

private struct XSTSAuthProperties: Encodable {
    let sandboxId: String
    let userTokens: [String]

    private enum CodingKeys: String, CodingKey {
        case sandboxId = "SandboxId"
        case userTokens = "UserTokens"
    }
}

private struct XboxAuthResponse: Decodable {
    let token: String
    let displayClaims: DisplayClaims

    var userHash: String {
        displayClaims.xui.first?.uhs ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case token = "Token"
        case displayClaims = "DisplayClaims"
    }
}

private struct DisplayClaims: Decodable {
    let xui: [XUIClaim]
}

private struct XUIClaim: Decodable {
    let uhs: String
}

private struct XboxAuthToken: Equatable {
    let token: String
    let userHash: String
}

private struct MinecraftLoginRequest: Encodable {
    let identityToken: String
}

private struct MinecraftTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct MinecraftProfileResponse: Decodable {
    let id: String
    let name: String
}

private struct MinecraftErrorResponse: Decodable {
    let error: String?
    let errorMessage: String?
    let path: String?

    var safeDescription: String {
        errorMessage ?? error ?? path ?? "Minecraft service returned an error."
    }
}
