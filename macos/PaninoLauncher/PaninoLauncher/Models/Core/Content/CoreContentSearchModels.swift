import Foundation

struct CoreContentSearchRequest: Encodable, Equatable, Sendable {
    let source: ContentSourceID
    let text: String
    let projectTypes: [OnlineProjectType]
    let categories: [String]
    let gameVersion: String?
    let loaders: [LoaderFamily]
    let sort: OnlineContentSort
    let offset: Int
    let limit: Int
    let curseForgeAPIKey: String?

    init(source: ContentSourceID, query: OnlineSearchQuery, curseForgeAPIKey: String?) {
        self.source = source
        self.text = query.text
        self.projectTypes = Array(query.projectTypes)
        self.categories = Array(query.categories)
        self.gameVersion = query.gameVersion
        self.loaders = Array(query.loaders)
        self.sort = query.sort
        self.offset = query.offset
        self.limit = query.limit
        self.curseForgeAPIKey = curseForgeAPIKey
    }
}

struct CoreContentProjectRequest: Encodable, Equatable, Sendable {
    let source: ContentSourceID
    let projectId: String
    let query: CoreContentSearchRequest
    let curseForgeAPIKey: String?
}

struct CoreContentProjectResponse: Decodable, Equatable, Sendable {
    let project: OnlineProject
    let releases: [OnlineRelease]
}
