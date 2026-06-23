import Foundation

struct CoreModpackPreflightRequest: Encodable, Equatable, Sendable {
    let sourceType: String
    let sourcePath: String?
    let targetGameDir: String?
}

struct CoreModpackPreflightResponse: Decodable, Equatable, Sendable {
    let valid: Bool
    let name: String?
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let modCount: Int
    let resourcePackCount: Int
    let shaderPackCount: Int
    let overridesCount: Int
    let estimatedDownloadBytes: Int64?
    let requiresApiKey: Bool
    let warnings: [String]
    let blockingReasons: [String]
    let typedPlan: CoreTypedInstallPlan
}

struct CoreModpackImportRequest: Encodable, Equatable, Sendable {
    let sourceType: String
    let sourcePath: String
    let targetGameDir: String
}

struct CoreModpackImportResponse: Decodable, Equatable, Sendable {
    let imported: Bool
    let targetGameDir: String
    let stagingPath: String
    let lockfilePath: String
    let filesWritten: Int
    let warnings: [String]
    let blockingReasons: [String]
    let typedPlan: CoreTypedInstallPlan
}

struct CoreExportBackupPreflightRequest: Encodable, Equatable, Sendable {
    let configuration: CoreGameConfigurationRequest
    let kind: String
    let targetPath: String?
}

struct CoreExportBackupPreflightResponse: Decodable, Equatable, Sendable {
    let allowed: Bool
    let warnings: [String]
    let blockingReasons: [String]
    let estimatedBytes: Int64?
    let checkedPaths: [String]
}
