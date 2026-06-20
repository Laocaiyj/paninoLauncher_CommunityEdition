import Foundation

extension LauncherApiClient {
    func task(id: String) async throws -> TaskSnapshot {
        try await send(path: "/api/v1/tasks/\(id)", method: "GET")
    }

    func taskHistory(statuses: [String]? = nil, kinds: [String]? = nil, limit: Int = 50, offset: Int = 0) async throws -> CoreTaskHistoryResponse {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/tasks/history"
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        if let statuses, !statuses.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: statuses.joined(separator: ",")))
        }
        if let kinds, !kinds.isEmpty {
            queryItems.append(URLQueryItem(name: "kind", value: kinds.joined(separator: ",")))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw LauncherApiError.invalidResponse }
        return try await send(authorizedRequest(url: url, method: "GET"))
    }

    func clearTaskHistory(_ request: CoreTaskHistoryClearRequest) async throws -> CoreTaskHistoryClearResponse {
        try await send(path: "/api/v1/tasks/history/clear", method: "POST", body: request)
    }

    func cancelTask(id: String) async throws -> TaskAccepted {
        try await send(path: "/api/v1/tasks/\(id)/cancel", method: "POST")
    }
}
