import Foundation

struct CoreJavaRuntimeDownloadSpec: Codable, Equatable, Sendable {
    let provider: String
    let vendor: String
    let featureVersion: Int
    let os: String
    let arch: String
    let imageType: String
    let url: String
    let checksumUrl: String?
    let sha256: String?
}

struct CoreJavaRuntimeCatalogItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let provider: String
    let vendor: String
    let featureVersion: Int
    let os: String
    let arch: String
    let imageType: String
    let download: CoreJavaRuntimeDownloadSpec
    let stale: Bool?
    let cachedAt: Date?
    let warnings: [String]
}
