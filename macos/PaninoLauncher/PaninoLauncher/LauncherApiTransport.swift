import Foundation

enum LauncherApiError: LocalizedError, Equatable {
    case invalidResponse
    case unexpectedStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Core returned an invalid HTTP response."
        case .unexpectedStatus(let statusCode, let body):
            return "Core returned HTTP \(statusCode): \(body)"
        }
    }
}

extension LauncherApiClient {
    func authorizedRequest(path: String, method: String = "GET") -> URLRequest {
        authorizedRequest(url: url(for: path), method: method)
    }

    func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(endpoint.sessionToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    func send<Response: Decodable>(path: String, method: String, body: some Encodable) async throws -> Response {
        var request = authorizedRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    func send<Response: Decodable>(path: String, method: String) async throws -> Response {
        try await send(authorizedRequest(path: path, method: method))
    }

    func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LauncherApiError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LauncherApiError.unexpectedStatus(httpResponse.statusCode, body)
        }

        return try Self.jsonDecoder.decode(Response.self, from: data)
    }

    func url(for path: String) -> URL {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components.url!
    }

    static func sanitizedGameDir(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func pathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = fractionalFormatter.date(from: value) ?? formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(value)")
        }
        return decoder
    }
}

struct LauncherApiInstallRequest: Encodable {
    let version: String
    let gameDir: String
    let loader: String?
    let loaderVersion: String?
    let shaderLoader: String?
    let shaderVersion: String?
    let instanceName: String?
    let concurrency: Int
    let retryCount: Int
    let download: CoreDownloadRuntimeOptions
}

struct LauncherApiLaunchRequest: Encodable {
    let version: String
    let gameDir: String
    let memoryMb: Int
    let java: String?
    let instanceId: String?
    let loader: String?
    let memoryPolicy: String?
    let jvmProfile: String?
    let customMemoryMb: Int?
    let username: String?
    let uuid: String?
    let accessToken: String?
    let jvmArgs: [String]
    let customJvmArgs: [String]
    let windowWidth: Int?
    let windowHeight: Int?
    let concurrency: Int
    let retryCount: Int
    let download: CoreDownloadRuntimeOptions
    let install: Bool
}

struct LauncherApiShutdownResponse: Decodable {
    let status: String
}
