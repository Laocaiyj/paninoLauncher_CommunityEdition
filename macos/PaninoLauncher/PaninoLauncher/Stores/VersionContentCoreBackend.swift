import Foundation

@MainActor
struct VersionContentCoreBackend {
    let minecraftVersions: () async throws -> [MinecraftRemoteVersion]
    let minecraftInstallStatus: (_ versionIds: [String], _ gameDirs: [String]) async throws -> [CoreMinecraftInstallStatus]
    let installedMinecraftInstances: (_ versionIds: [String], _ gameDirs: [String]) async throws -> [CoreInstalledMinecraftInstance]
    let minecraftPackage: (MinecraftRemoteVersion) async throws -> MinecraftVersionPackage
    let localResources: (_ gameDir: String, _ kind: ManagedAssetKind, _ loader: LoaderKind) async throws -> [CoreManagedAsset]
    let toggleLocalResource: (_ path: String) async throws -> CoreLocalResourceMutationResponse
    let deleteLocalResource: (_ path: String) async throws -> CoreLocalResourceMutationResponse
    let importLocalResource: (_ sourcePath: String, _ gameDir: String, _ kind: ManagedAssetKind) async throws -> CoreLocalResourceMutationResponse
    let cleanMinecraftVersion: (_ version: String, _ gameDir: String) async throws -> CoreLocalResourceMutationResponse
    let mutateMinecraftVersionStorage: (_ version: String, _ gameDir: String, _ action: CoreMinecraftVersionStorageAction) async throws -> CoreLocalResourceMutationResponse
}
