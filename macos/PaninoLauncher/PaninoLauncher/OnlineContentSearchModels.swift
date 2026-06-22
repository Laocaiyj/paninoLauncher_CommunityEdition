import Foundation

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
