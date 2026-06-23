import Foundation

struct MinecraftRemoteVersion: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String
    let url: URL
    let releasedAt: Date?
}

struct MinecraftVersionPackage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String
    let javaMajorVersion: Int?
    let assetIndex: MinecraftAssetIndex?
    let downloads: [MinecraftDownloadKind: MinecraftDownload]
    let libraryCount: Int?
    let nativeLibraryCount: Int
}

enum MinecraftDownloadKind: String, Codable, CaseIterable, Sendable {
    case client
    case clientMappings = "client_mappings"
    case server
    case serverMappings = "server_mappings"
}

struct MinecraftDownload: Codable, Equatable, Sendable {
    let url: URL
    let sha1: String?
    let sizeBytes: Int64?
}

struct MinecraftAssetIndex: Codable, Equatable, Sendable {
    let id: String
    let url: URL
    let sha1: String?
    let sizeBytes: Int64?
    let totalSizeBytes: Int64?
}

struct LoaderMetadata: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let source: ContentSourceID
    let minecraftVersion: String
    let loaderVersion: String
    let installerVersion: String?
    let stable: Bool
    let downloadURL: URL?
}

enum OnlineContentError: LocalizedError, Equatable, Sendable {
    case invalidURL(String)
    case invalidResponse
    case unexpectedStatus(Int, String)
    case rateLimited(TimeInterval?)
    case authenticationRequired(ContentSourceID)
    case responseTooLarge(Int)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid content source URL: \(value)"
        case .invalidResponse:
            return "The content source returned an invalid HTTP response."
        case .unexpectedStatus(let status, let body):
            return "The content source returned HTTP \(status): \(body)"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "The content source is rate limited. Retry after \(Int(retryAfter)) seconds."
            }
            return "The content source is rate limited. Retry later."
        case .authenticationRequired(let source):
            return "\(source.displayName) requires API credentials before browsing."
        case .responseTooLarge(let size):
            return "The content source response is too large to process safely (\(size) bytes)."
        case .decodingFailed(let message):
            return "Failed to parse content source response: \(message)"
        }
    }
}
