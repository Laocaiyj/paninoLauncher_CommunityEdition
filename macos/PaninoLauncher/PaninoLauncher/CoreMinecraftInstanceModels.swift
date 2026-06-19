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

struct CoreGameConfigurationRequest: Codable, Equatable, Sendable {
    let id: String?
    let name: String
    let minecraftVersion: String
    let loader: String?
    let loaderVersion: String?
    let gameDir: String
    let javaPath: String?
    let memoryMb: Int
    let memoryPolicy: String
    let jvmProfile: String
    let graphicsProfile: String
    let customMemoryMb: Int?
    let customJvmArgs: [String]
    let status: String?
    let isFavorite: Bool
    let lastLaunchedAt: String?
    let lastLaunchState: String?
    let launchCount: Int
    let isHiddenFromRecent: Bool

    init(instance: GameInstance) {
        self.id = instance.id.uuidString
        self.name = instance.name
        self.minecraftVersion = instance.minecraftVersion
        self.loader = instance.loader?.rawValue
        self.loaderVersion = instance.loaderVersion
        self.gameDir = instance.gameDirectory
        self.javaPath = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instance.javaPath
        self.memoryMb = instance.memoryMb
        self.memoryPolicy = instance.memoryPolicy.rawValue
        self.jvmProfile = instance.jvmProfile.rawValue
        self.graphicsProfile = instance.graphicsProfile.rawValue
        self.customMemoryMb = instance.customMemoryMb
        self.customJvmArgs = splitJvmArguments(instance.customJvmArguments)
        self.status = instance.status.rawValue
        self.isFavorite = instance.isFavorite
        self.lastLaunchedAt = instance.lastLaunchedAt.map { ISO8601DateFormatter().string(from: $0) }
        self.lastLaunchState = instance.lastLaunchState?.rawValue
        self.launchCount = instance.launchCount
        self.isHiddenFromRecent = instance.isHiddenFromRecent
    }
}

func splitJvmArguments(_ value: String) -> [String] {
    var result: [String] = []
    var current = ""
    var quote: Character?
    var escaping = false

    for char in value {
        if escaping {
            current.append(char)
            escaping = false
            continue
        }
        if char == "\\" {
            escaping = true
            continue
        }
        if let activeQuote = quote {
            if char == activeQuote {
                quote = nil
            } else {
                current.append(char)
            }
            continue
        }
        if char == "\"" || char == "'" {
            quote = char
            continue
        }
        if char.isWhitespace {
            if !current.isEmpty {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            }
        } else {
            current.append(char)
        }
    }
    if escaping {
        current.append("\\")
    }
    if !current.isEmpty {
        result.append(current)
    }
    return result
}

struct CoreLaunchLibraryRequest: Encodable, Equatable, Sendable {
    let configurations: [CoreGameConfigurationRequest]

    init(instances: [GameInstance]) {
        self.configurations = instances.map(CoreGameConfigurationRequest.init(instance:))
    }
}

struct CoreLaunchContentSummary: Decodable, Equatable, Sendable {
    let modCount: Int
    let resourcePackCount: Int
    let shaderPackCount: Int
    let saveCount: Int
    let logCount: Int
    let conflictCount: Int
    let warningCount: Int
}

struct CoreLaunchInstanceSummary: Decodable, Equatable, Identifiable, Sendable {
    let id: String?
    let name: String
    let minecraftVersion: String
    let loader: String?
    let gameDir: String
    let status: String
    let canLaunch: Bool
    let needsAttention: Bool
    let attentionReasons: [String]
    let isFavorite: Bool
    let lastLaunchedAt: String?
    let lastLaunchState: String?
    let launchCount: Int
    let isHiddenFromRecent: Bool
    let installedAt: String?
    let content: CoreLaunchContentSummary
    let diskUsageBytes: Int64?

    var stableID: String { id ?? "\(minecraftVersion)|\(gameDir)" }
}

struct CoreLaunchLibraryResponse: Decodable, Equatable, Sendable {
    let instances: [CoreLaunchInstanceSummary]
    let totalCount: Int
    let readyCount: Int
    let attentionCount: Int
    let recentIds: [String]
    let recentInstallIds: [String]?
    let favoriteIds: [String]
    let attentionIds: [String]
}

struct CoreConfigurationCapabilities: Decodable, Equatable, Sendable {
    let canLaunch: Bool
    let canManageMods: Bool
    let canManageResourcePacks: Bool
    let canManageShaderPacks: Bool
    let canInstallLoader: Bool
    let canExportModpack: Bool
    let canBackupSaves: Bool
    let canRepair: Bool
    let reasons: [String]
}

struct CoreLoaderCompatibilityEntry: Decodable, Equatable, Sendable {
    let loader: String
    let available: Bool
    let recommendedVersion: String?
    let versions: [String]
    let reason: String?
    let experimental: Bool
}

struct CoreLoaderCompatibilityResponse: Decodable, Equatable, Sendable {
    let minecraftVersion: String
    let options: [CoreLoaderCompatibilityEntry]
}

struct CoreVersionSwitchPreflightRequest: Encodable, Equatable, Sendable {
    let configuration: CoreGameConfigurationRequest
    let targetMinecraftVersion: String
}

struct CoreVersionSwitchPreflightResponse: Decodable, Equatable, Sendable {
    let allowed: Bool
    let recommendedAction: String
    let warnings: [String]
    let blockingReasons: [String]
    let capabilities: CoreConfigurationCapabilities
}

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
