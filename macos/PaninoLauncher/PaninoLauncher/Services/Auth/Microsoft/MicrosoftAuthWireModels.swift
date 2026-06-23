import Foundation

enum MicrosoftAuthEndpoints {
    static let scope = "XboxLive.signin offline_access"
    static let deviceCode = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
    static let token = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
    static let xboxUserAuth = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
    static let xstsAuthorize = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
    static let minecraftLogin = URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!
    static let minecraftProfile = URL(string: "https://api.minecraftservices.com/minecraft/profile")!
}

struct DeviceCodeResponse: Decodable {
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

struct MicrosoftTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

struct OAuthServiceError: Error {
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

struct XboxUserAuthRequest: Encodable {
    let properties: XboxUserAuthProperties
    let relyingParty: String
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case properties = "Properties"
        case relyingParty = "RelyingParty"
        case tokenType = "TokenType"
    }
}

struct XboxUserAuthProperties: Encodable {
    let authMethod: String
    let siteName: String
    let rpsTicket: String

    private enum CodingKeys: String, CodingKey {
        case authMethod = "AuthMethod"
        case siteName = "SiteName"
        case rpsTicket = "RpsTicket"
    }
}

struct XSTSAuthRequest: Encodable {
    let properties: XSTSAuthProperties
    let relyingParty: String
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case properties = "Properties"
        case relyingParty = "RelyingParty"
        case tokenType = "TokenType"
    }
}

struct XSTSAuthProperties: Encodable {
    let sandboxId: String
    let userTokens: [String]

    private enum CodingKeys: String, CodingKey {
        case sandboxId = "SandboxId"
        case userTokens = "UserTokens"
    }
}

struct XboxAuthResponse: Decodable {
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

struct DisplayClaims: Decodable {
    let xui: [XUIClaim]
}

struct XUIClaim: Decodable {
    let uhs: String
}

struct XboxAuthToken: Equatable {
    let token: String
    let userHash: String
}

struct MinecraftLoginRequest: Encodable {
    let identityToken: String
}

struct MinecraftTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct MinecraftProfileResponse: Decodable {
    let id: String
    let name: String
}

struct MinecraftErrorResponse: Decodable {
    let error: String?
    let errorMessage: String?
    let path: String?

    var safeDescription: String {
        errorMessage ?? error ?? path ?? "Minecraft service returned an error."
    }
}
