import Foundation

struct CoreMinecraftPackageRequest: Encodable, Equatable, Sendable {
    let id: String
    let url: URL
}

struct CoreMinecraftInstallStatusRequest: Encodable, Equatable, Sendable {
    let versionIds: [String]
    let gameDirs: [String]
}

struct CoreMinecraftInstallStatus: Decodable, Equatable, Sendable {
    let versionId: String
    let installed: Bool
    let versionJson: Bool
    let clientJar: Bool
    let diskUsageBytes: Int64?
    let installRoot: String?
    let archived: Bool
    let archivePath: String?
}

struct CoreInstalledMinecraftInstance: Decodable, Equatable, Sendable {
    let versionId: String
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let name: String?
    let gameDir: String
    let versionJson: Bool
    let clientJar: Bool
    let diskUsageBytes: Int64?
    let archived: Bool
    let archivePath: String?
}

struct CoreContentLoaderRequest: Encodable, Equatable, Sendable {
    let minecraftVersion: String
}
