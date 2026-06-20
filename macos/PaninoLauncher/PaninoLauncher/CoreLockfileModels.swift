import Foundation

struct CoreLockfilePlatform: Codable, Equatable, Sendable {
    let family: String?
    let version: String?
    let major: Int?
    let runtimeId: String?
    let source: String?
    let path: String?
}

struct CoreLockfileFile: Codable, Equatable, Sendable {
    let packageId: String
    let fileName: String
    let targetPath: String
    let hashes: [String: String]
    let size: Int64?
    let downloadUrls: [String]
    let kind: String
}

struct CorePaninoLockfile: Codable, Equatable, Sendable {
    let lockfileVersion: Int
    let solverVersion: String
    let fingerprint: String
    let createdAt: Date?
    let updatedAt: Date?
    let targetGameDir: String?
    let minecraft: String?
    let java: CoreLockfilePlatform?
    let loader: CoreLockfilePlatform?
    let shaderLoader: CoreLockfilePlatform?
    let roots: [String]
    let packages: [CoreResolvedPackage]
    let files: [CoreLockfileFile]
    let constraints: [CorePackageConstraint]
    let overrides: [String]
    let sourceSnapshots: [String]
    let manualEntries: [CoreResolvedPackage]
    let warnings: [String]
}
