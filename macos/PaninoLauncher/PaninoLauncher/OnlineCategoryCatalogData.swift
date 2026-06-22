import Foundation

extension OnlineCategoryCatalog {
    static let all: [OnlineCategoryOption] = modCategories + visualCategories + gameplayCategories

    static let modrinthSources: Set<ContentSourceID> = [.modrinth]
    static let bothSources: Set<ContentSourceID> = [.modrinth, .curseForge]
}
