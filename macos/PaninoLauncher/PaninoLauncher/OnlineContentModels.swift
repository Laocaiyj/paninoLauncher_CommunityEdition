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
