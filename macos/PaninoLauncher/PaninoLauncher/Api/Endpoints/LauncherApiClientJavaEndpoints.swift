import Foundation

extension LauncherApiClient {
    func checkJavaRuntime(_ request: CoreJavaCheckRequest) async throws -> JavaRuntimeStatus {
        try await send(path: "/api/v1/runtime/java/check", method: "POST", body: request)
    }

    func scanJavaRuntimes() async throws -> [JavaRuntimeCandidate] {
        try await send(path: "/api/v1/runtime/java/scan", method: "GET")
    }

    func managedJavaRuntimes() async throws -> CoreJavaManagedResponse {
        try await send(path: "/api/v1/runtime/java/managed", method: "GET")
    }

    func resolveJavaRuntime(_ request: CoreJavaRuntimeResolveRequest) async throws -> CoreJavaRuntimeResolveResponse {
        try await send(path: "/api/v1/runtime/java/resolve", method: "POST", body: request)
    }

    func javaRuntimeCatalog(featureVersion: Int, os: String? = nil, arch: String? = nil, imageType: String = "jre", provider: String? = nil) async throws -> [CoreJavaRuntimeCatalogItem] {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/runtime/java/catalog"
        var queryItems = [
            URLQueryItem(name: "featureVersion", value: String(featureVersion)),
            URLQueryItem(name: "imageType", value: imageType)
        ]
        if let os, !os.isEmpty {
            queryItems.append(URLQueryItem(name: "os", value: os))
        }
        if let arch, !arch.isEmpty {
            queryItems.append(URLQueryItem(name: "arch", value: arch))
        }
        if let provider, !provider.isEmpty {
            queryItems.append(URLQueryItem(name: "provider", value: provider))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw LauncherApiError.invalidResponse }
        return try await send(authorizedRequest(url: url, method: "GET"))
    }

    func selectJavaRuntime(_ request: CoreJavaRuntimeSelectRequest) async throws -> CoreJavaRuntimeSelectResponse {
        try await send(path: "/api/v1/runtime/java/select", method: "POST", body: request)
    }

    func installJavaRuntime(_ request: CoreJavaRuntimeInstallRequest) async throws -> TaskAccepted {
        try await send(path: "/api/v1/runtime/java/install", method: "POST", body: request)
    }

    func importJavaRuntime(_ request: CoreJavaRuntimeImportRequest) async throws -> CoreJavaManagedRuntime {
        try await send(path: "/api/v1/runtime/java/import", method: "POST", body: request)
    }

    func cleanupJavaRuntimes() async throws -> CoreJavaRuntimeCleanupResponse {
        try await send(path: "/api/v1/runtime/java/cleanup", method: "POST")
    }

    func verifyJavaRuntime(id: String) async throws -> CoreJavaManagedRuntime {
        try await send(path: "/api/v1/runtime/java/verify", method: "POST", body: CoreJavaRuntimeVerifyRequest(id: id))
    }

    func deleteJavaRuntime(id: String) async throws -> CoreJavaRuntimeDeleteResponse {
        let escapedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await send(path: "/api/v1/runtime/java/managed/\(escapedID)", method: "DELETE")
    }

    func deleteLocalJavaRuntime(path: String) async throws -> CoreJavaRuntimeLocalDeleteResponse {
        try await send(
            path: "/api/v1/runtime/java/local/delete",
            method: "POST",
            body: CoreJavaRuntimeLocalDeleteRequest(path: path)
        )
    }
}
