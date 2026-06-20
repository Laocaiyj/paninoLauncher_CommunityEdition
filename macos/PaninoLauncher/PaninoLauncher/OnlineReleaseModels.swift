import Foundation

enum OnlineReleaseType: String, Codable, Sendable {
    case release
    case beta
    case alpha
    case snapshot
    case unknown
}

enum OnlineDependencyRelation: String, Codable, Sendable {
    case required
    case optional
    case incompatible
    case embedded
    case unknown
}

struct OnlineRelease: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let projectID: String
    let source: ContentSourceID
    let versionName: String
    let versionNumber: String
    let gameVersions: [String]
    let loaders: [LoaderFamily]
    let releaseType: OnlineReleaseType
    let publishedAt: Date?
    let files: [OnlineFile]
    let dependencies: [OnlineDependency]
    let changelog: String?
    let isRecommended: Bool
}

struct OnlineFile: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let fileName: String
    let sizeBytes: Int64
    let downloadURL: URL?
    let hashes: [String: String]
    let isPrimary: Bool
    let downloadCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case fileName
        case sizeBytes
        case downloadURL
        case hashes
        case isPrimary
        case downloadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
        downloadURL = container.lossyURL(forKey: .downloadURL)
        hashes = try container.decode([String: String].self, forKey: .hashes)
        isPrimary = try container.decode(Bool.self, forKey: .isPrimary)
        downloadCount = try container.decodeIfPresent(Int.self, forKey: .downloadCount)
    }
}

struct OnlineDependency: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let projectID: String?
    let versionID: String?
    let source: ContentSourceID
    let relation: OnlineDependencyRelation
}
