import Foundation

struct MicrosoftOAuthTokenClient {
    private let httpClient: MicrosoftAuthHTTPClient

    init(httpClient: MicrosoftAuthHTTPClient = MicrosoftAuthHTTPClient()) {
        self.httpClient = httpClient
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

    func pollForToken(clientId: String, deviceSession: DeviceCodeSession) async throws -> MicrosoftTokenResponse {
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

    func refreshToken(clientId: String, refreshToken: String) async throws -> MicrosoftTokenResponse {
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
}
