import Foundation

enum ContentSourceID: String, Codable, CaseIterable, Identifiable, Sendable {
    case modrinth
    case curseForge
    case mojang
    case fabric
    case quilt
    case forge
    case neoForge
    case github
    case hangar
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modrinth: return "Modrinth"
        case .curseForge: return "CurseForge"
        case .mojang: return "Mojang/Piston Meta"
        case .fabric: return "Fabric Meta"
        case .quilt: return "Quilt Meta"
        case .forge: return "Forge"
        case .neoForge: return "NeoForge"
        case .github: return "GitHub Releases"
        case .hangar: return "Hangar"
        case .custom: return "Custom"
        }
    }
}

enum OnlineProjectType: String, Codable, CaseIterable, Identifiable, Sendable {
    case mod
    case modpack
    case resourcePack
    case shaderPack
    case plugin
    case minecraftVersion
    case loader

    var id: String { rawValue }
}

enum OnlineSideSupport: String, Codable, Sendable {
    case required
    case optional
    case unsupported
    case unknown
}

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

enum LoaderFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case fabric
    case quilt
    case forge
    case neoForge

    var id: String { rawValue }
}

enum OnlineContentSort: String, Codable, CaseIterable, Sendable {
    case relevance
    case downloads
    case updated
    case newest
    case follows
}

struct OnlineSearchQuery: Codable, Equatable, Sendable {
    var text: String
    var projectTypes: Set<OnlineProjectType>
    var categories: Set<String>
    var gameVersion: String?
    var loaders: Set<LoaderFamily>
    var sort: OnlineContentSort
    var offset: Int
    var limit: Int

    init(
        text: String = "",
        projectTypes: Set<OnlineProjectType> = [.mod],
        categories: Set<String> = [],
        gameVersion: String? = nil,
        loaders: Set<LoaderFamily> = [],
        sort: OnlineContentSort = .relevance,
        offset: Int = 0,
        limit: Int = 20
    ) {
        self.text = text
        self.projectTypes = projectTypes
        self.categories = categories
        self.gameVersion = gameVersion
        self.loaders = loaders
        self.sort = sort
        self.offset = max(offset, 0)
        self.limit = min(max(limit, 1), 50)
    }

    func diagnosticSummary(source: ContentSourceID) -> String {
        let categorySummary = categories.sorted().joined(separator: ",")
        let typeSummary = projectTypes.map(\.rawValue).sorted().joined(separator: ",")
        let loaderSummary = loaders.map(\.rawValue).sorted().joined(separator: ",")
        return [
            "source=\(source.rawValue)",
            "text=\(text.trimmingCharacters(in: .whitespacesAndNewlines))",
            "type=\(typeSummary)",
            "category=\(categorySummary)",
            "version=\(gameVersion ?? "")",
            "loader=\(loaderSummary)",
            "sort=\(sort.rawValue)",
            "offset=\(offset)",
            "limit=\(limit)"
        ].joined(separator: " ")
    }
}

struct OnlineSearchPage: Codable, Equatable, Sendable {
    let source: ContentSourceID
    let projects: [OnlineProject]
    let total: Int
    let offset: Int
    let limit: Int
    let rateLimit: OnlineRateLimit?
    let cacheStatus: String?
    let requestId: String?
    let hasMore: Bool?
    let nextPrefetchKey: String?
}

struct OnlineRateLimit: Codable, Equatable, Sendable {
    let limit: Int?
    let remaining: Int?
    let resetAt: Date?
    let retryAfterSeconds: TimeInterval?
}

struct OnlineProject: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let source: ContentSourceID
    let slug: String?
    let title: String
    let summary: String
    let description: String?
    let iconURL: URL?
    let galleryURLs: [URL]
    let authors: [String]
    let projectURL: URL?
    let projectType: OnlineProjectType
    let downloads: Int
    let follows: Int?
    let updatedAt: Date?
    let gameVersions: [String]
    let loaders: [LoaderFamily]
    let clientSide: OnlineSideSupport
    let serverSide: OnlineSideSupport
    let license: String?
    let isArchived: Bool
    let isDeprecated: Bool
    let categories: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case slug
        case title
        case summary
        case description
        case iconURL
        case galleryURLs
        case authors
        case projectURL
        case projectType
        case downloads
        case follows
        case updatedAt
        case gameVersions
        case loaders
        case clientSide
        case serverSide
        case license
        case isArchived
        case isDeprecated
        case categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        source = try container.decode(ContentSourceID.self, forKey: .source)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconURL = container.lossyURL(forKey: .iconURL)
        galleryURLs = container.lossyURLArray(forKey: .galleryURLs)
        authors = try container.decode([String].self, forKey: .authors)
        projectURL = container.lossyURL(forKey: .projectURL)
        projectType = try container.decode(OnlineProjectType.self, forKey: .projectType)
        downloads = try container.decode(Int.self, forKey: .downloads)
        follows = try container.decodeIfPresent(Int.self, forKey: .follows)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        gameVersions = try container.decode([String].self, forKey: .gameVersions)
        loaders = try container.decode([LoaderFamily].self, forKey: .loaders)
        clientSide = try container.decode(OnlineSideSupport.self, forKey: .clientSide)
        serverSide = try container.decode(OnlineSideSupport.self, forKey: .serverSide)
        license = try container.decodeIfPresent(String.self, forKey: .license)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        isDeprecated = try container.decode(Bool.self, forKey: .isDeprecated)
        categories = try container.decode([String].self, forKey: .categories)
    }
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

private extension KeyedDecodingContainer {
    func lossyURL(forKey key: Key) -> URL? {
        guard let raw = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        return Self.url(from: raw)
    }

    func lossyURLArray(forKey key: Key) -> [URL] {
        guard let values = try? decodeIfPresent([String].self, forKey: key) else { return [] }
        return values.compactMap(Self.url(from:))
    }

    private static func url(from raw: String?) -> URL? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

enum OnlineInstallPlanAction: String, Sendable {
    case install
    case update
    case alreadyInstalled
    case unsupported
    case blocked
}

struct OnlineInstallPlan: Identifiable, Equatable, Sendable {
    let id: String
    let projectTitle: String
    let releaseTitle: String
    let projectType: OnlineProjectType
    let managedKind: ManagedAssetKind?
    let sourceURL: URL?
    let destinationURL: URL?
    let targetConfigurationName: String?
    let targetMinecraftVersion: String?
    let fileName: String
    let fileSizeBytes: Int64
    let hashes: [String: String]
    let action: OnlineInstallPlanAction
    let dependencies: [OnlineDependency]
    let warnings: [String]
    let blockingReasons: [String]
}

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
