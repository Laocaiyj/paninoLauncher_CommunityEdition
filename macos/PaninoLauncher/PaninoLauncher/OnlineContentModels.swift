import Foundation

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
