import Foundation

struct CorePackageCoordinate: Codable, Equatable, Sendable {
    let source: String
    let projectId: String?
    let versionId: String?
    let fileId: String?
    let slug: String?
    let name: String?
    let kind: String
}

struct CorePackageConstraint: Codable, Equatable, Sendable {
    let constraintId: String
    let sourcePackage: String?
    let targetPackageId: String?
    let targetKind: String
    let relation: String
    let minecraftVersions: [String]
    let loaders: [String]
    let javaMajor: Int?
    let side: String?
    let required: Bool
    let reason: String
}

struct CoreResolvedPackage: Codable, Equatable, Sendable {
    let packageId: String
    let coordinate: CorePackageCoordinate
    let displayName: String
    let versionName: String?
    let fileName: String?
    let targetPath: String?
    let hashes: [String: String]
    let size: Int64?
    let downloadUrls: [String]
    let gameVersions: [String]
    let loaders: [String]
    let javaMajor: Int?
    let side: String?
    let selectedBecause: [String]
    let locked: Bool
    let pinReason: String?
    let dependencies: [CorePackageConstraint]
    let conflicts: [CorePackageConstraint]
    let sourceSnapshot: String?
}

struct CoreSolverConflict: Codable, Equatable, Sendable {
    let conflictId: String
    let code: String
    let title: String
    let message: String
    let packageIds: [String]
    let filePaths: [String]
    let diagnostic: CoreDiagnostic?
}
