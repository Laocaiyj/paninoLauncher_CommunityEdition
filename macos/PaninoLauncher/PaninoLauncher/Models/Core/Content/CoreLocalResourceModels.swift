import Foundation

struct CoreLocalResourceScanRequest: Encodable, Equatable, Sendable {
    let gameDir: String
    let kind: ManagedAssetKind
    let loader: LoaderKind?
}

struct CoreLocalResourcePathRequest: Encodable, Equatable, Sendable {
    let path: String
}

struct CoreLocalResourceImportRequest: Encodable, Equatable, Sendable {
    let sourcePath: String
    let gameDir: String
    let kind: ManagedAssetKind
}

struct CoreLocalArchiveRequest: Encodable, Equatable, Sendable {
    let sourcePath: String
    let targetPath: String
}

struct CoreLocalArchiveImportRequest: Encodable, Equatable, Sendable {
    let archivePath: String
    let targetDir: String
    let deleteArchive: Bool
}

struct CoreMinecraftCleanVersionRequest: Encodable, Equatable, Sendable {
    let version: String
    let gameDir: String
}

enum CoreMinecraftVersionStorageAction: String, Encodable, Equatable, Sendable {
    case delete
    case archive
    case restore
}

struct CoreMinecraftVersionStorageRequest: Encodable, Equatable, Sendable {
    let version: String
    let gameDir: String
    let action: CoreMinecraftVersionStorageAction
}

struct CoreLocalResourceMutationResponse: Decodable, Equatable, Sendable {
    let changed: Bool
    let path: String?
    let message: String
}

struct CoreManagedAsset: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let path: String
    let isEnabled: Bool
    let conflictMessage: String?
    let metadata: ManagedAssetMetadata
    let fileSizeBytes: Int64
    let modifiedAt: Date?
    let source: String?
    let projectURL: URL?
}
