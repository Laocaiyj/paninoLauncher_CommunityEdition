import Foundation

struct MicrosoftAuthHTTPClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 90
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: configuration)
    }

    func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
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

    func formRequest(url: URL, fields: [String: String]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded(fields).data(using: .utf8)
        return request
    }

    func jsonRequest<Body: Encodable>(url: URL, body: Body) throws -> URLRequest {
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
}
