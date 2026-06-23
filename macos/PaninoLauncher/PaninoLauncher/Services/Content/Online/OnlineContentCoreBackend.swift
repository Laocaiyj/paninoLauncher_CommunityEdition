import Foundation

@MainActor
struct OnlineContentCoreBackend {
    let search: (OnlineSearchQuery, ContentSourceID, String?) async throws -> OnlineSearchPage
    let project: (String, ContentSourceID, OnlineSearchQuery, String?) async throws -> CoreContentProjectResponse
    let minecraftVersions: () async throws -> [MinecraftRemoteVersion]
    let minecraftPackage: (MinecraftRemoteVersion) async throws -> MinecraftVersionPackage
    let loaderMetadata: (String) async throws -> [LoaderMetadata]
}
