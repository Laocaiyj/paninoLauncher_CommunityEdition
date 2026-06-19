import Foundation

struct CoreJavaCheckRequest: Encodable, Equatable, Sendable {
    let java: String?
}

struct CoreJavaManagedResponse: Codable, Equatable, Sendable {
    let runtimes: [CoreJavaManagedRuntime]
    let root: String
}

struct CoreJavaManagedRuntime: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let vendor: String
    let provider: String
    let featureVersion: Int
    let version: String
    let os: String
    let arch: String
    let imageType: String
    let javaHome: String
    let javaExecutable: String
    let sourceUrl: String
    let sha256: String?
    let installedAt: Date
    let lastVerifiedAt: Date?
    let diskUsageBytes: Int64?
    let usedByInstanceCount: Int

    var displayName: String {
        "Java \(featureVersion)"
    }

    var detailText: String {
        [
            vendor.capitalized,
            osDisplayName,
            archDisplayName,
            imageType.uppercased(),
            diskUsageBytes.map { formattedBytes($0) }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var osDisplayName: String {
        os == "mac" ? "macOS" : os
    }

    private var archDisplayName: String {
        switch arch {
        case "aarch64":
            return "ARM64"
        case "x64":
            return "x64"
        default:
            return arch
        }
    }
}

struct CoreJavaRuntimeDownloadSpec: Codable, Equatable, Sendable {
    let provider: String
    let vendor: String
    let featureVersion: Int
    let os: String
    let arch: String
    let imageType: String
    let url: String
    let checksumUrl: String?
    let sha256: String?
}

struct CoreJavaRuntimeCatalogItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let provider: String
    let vendor: String
    let featureVersion: Int
    let os: String
    let arch: String
    let imageType: String
    let download: CoreJavaRuntimeDownloadSpec
    let stale: Bool?
    let cachedAt: Date?
    let warnings: [String]
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

struct JavaRuntimeCandidate: Decodable, Identifiable, Equatable, Sendable {
    let path: String
    let isAvailable: Bool
    let versionSummary: String
    let source: String
    let canDelete: Bool?
    let deleteTarget: String?

    var id: String { path }

    var displayText: String {
        cleanVersionSummary.isEmpty ? path : cleanVersionSummary
    }

    var hasMeaningfulSummary: Bool {
        !cleanVersionSummary.isEmpty
    }

    var pathDetailText: String {
        path.isEmpty ? "java" : path
    }

    var supportsDeletion: Bool {
        canDelete == true && !(deleteTarget?.isEmpty ?? true)
    }

    private var cleanVersionSummary: String {
        let trimmed = versionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.localizedCaseInsensitiveCompare("Property settings:") != .orderedSame else {
            return ""
        }
        return trimmed
    }
}

struct JavaRuntimeStatus: Codable, Equatable, Sendable {
    let path: String
    let isAvailable: Bool
    let versionSummary: String
    let version: String?
    let majorVersion: Int?
    let vendor: String?
    let architecture: String?
    let executablePermission: Bool?
    let rawSummary: String?

    init(
        path: String,
        isAvailable: Bool,
        versionSummary: String,
        version: String? = nil,
        majorVersion: Int? = nil,
        vendor: String? = nil,
        architecture: String? = nil,
        executablePermission: Bool? = nil,
        rawSummary: String? = nil
    ) {
        self.path = path
        self.isAvailable = isAvailable
        self.versionSummary = versionSummary
        self.version = version
        self.majorVersion = majorVersion
        self.vendor = vendor
        self.architecture = architecture
        self.executablePermission = executablePermission
        self.rawSummary = rawSummary
    }

    var displayText: String {
        if isAvailable {
            return versionSummary.isEmpty ? "Java available" : versionSummary
        }
        return versionSummary.isEmpty ? "Java unavailable" : versionSummary
    }
}
