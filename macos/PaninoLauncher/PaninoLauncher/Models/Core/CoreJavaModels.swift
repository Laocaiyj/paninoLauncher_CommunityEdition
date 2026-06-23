import Foundation

struct CoreJavaCheckRequest: Encodable, Equatable, Sendable {
    let java: String?
}

struct CoreJavaRuntimeResolveRequest: Encodable, Equatable, Sendable {
    let minecraftVersion: String
    let gameDir: String?
    let instanceId: String?
    let policy: String?
    let preferredRuntimeId: String?
    let customPath: String?
}

struct CoreJavaRuntimeResolveResponse: Codable, Equatable, Sendable {
    let minecraftVersion: String
    let requiredMajorVersion: Int
    let source: String
    let policy: String
    let status: String
    let selectedRuntimeId: String?
    let javaExecutable: String?
    let download: CoreJavaRuntimeDownloadSpec?
    let actions: [String]
    let warnings: [String]
    let blockingReasons: [String]

    var isReady: Bool { status == "ready" }
    var isDownloadable: Bool { status == "downloadable" }

    var conciseStatus: String {
        switch status {
        case "ready":
            if selectedRuntimeId != nil {
                return "Auto · Java \(requiredMajorVersion) · Panino"
            }
            return "Auto · Java \(requiredMajorVersion) · Ready"
        case "downloadable":
            return "Java \(requiredMajorVersion) needs download"
        case "incompatible":
            return "Java \(requiredMajorVersion) is incompatible"
        case "missing":
            return "Java \(requiredMajorVersion) is missing"
        case "blocked":
            return blockingReasons.first ?? "Java runtime is blocked"
        default:
            return "Java \(requiredMajorVersion) · \(status)"
        }
    }
}

struct CoreJavaRuntimeInstallRequest: Encodable, Equatable, Sendable {
    let featureVersion: Int
    let provider: String
    let vendor: String
    let os: String?
    let arch: String?
    let imageType: String
    let setDefault: Bool
    let download: CoreDownloadRuntimeOptions
}

struct CoreJavaRuntimeSelectRequest: Encodable, Equatable, Sendable {
    let scope: String
    let instanceId: String?
    let policy: String
    let preferredRuntimeId: String?
    let customPath: String?
    let lockPatchVersion: Bool
}

struct CoreJavaRuntimePolicyRecord: Codable, Equatable, Sendable {
    let scope: String
    let instanceId: String?
    let policy: String
    let preferredRuntimeId: String?
    let customPath: String?
    let lockPatchVersion: Bool
    let updatedAt: Date
}

struct CoreJavaRuntimeSelectResponse: Decodable, Equatable, Sendable {
    let policy: CoreJavaRuntimePolicyRecord
    let message: String
}

struct CoreJavaRuntimeImportRequest: Encodable, Equatable, Sendable {
    let sourcePath: String
    let provider: String
    let vendor: String
    let featureVersion: Int?
    let os: String?
    let arch: String?
    let imageType: String
    let setDefault: Bool
}

struct CoreJavaRuntimeVerifyRequest: Encodable, Equatable, Sendable {
    let id: String
}

struct CoreJavaRuntimeLocalDeleteRequest: Encodable, Equatable, Sendable {
    let path: String
}

struct CoreJavaRuntimeLocalDeleteResponse: Decodable, Equatable, Sendable {
    let deleted: Bool
    let path: String
    let targetRoot: String?
    let message: String
}

struct CoreJavaRuntimeDeleteResponse: Decodable, Equatable, Sendable {
    let deleted: Bool
    let id: String
    let message: String
    let references: [String]?
}

struct CoreJavaRuntimeCleanupResponse: Decodable, Equatable, Sendable {
    let deletedRuntimeIds: [String]
    let deletedDownloadFiles: [String]
    let deletedStagingDirs: [String]
    let freedBytes: Int64
    let keptRuntimeIds: [String]
    let message: String
}
