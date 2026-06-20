import Foundation

enum ManagedAssetKind: String, Codable, CaseIterable, Identifiable {
    case mods
    case resourcePacks
    case shaderPacks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mods:
            return "Mods"
        case .resourcePacks:
            return "Resource Packs"
        case .shaderPacks:
            return "Shader Packs"
        }
    }

    var folderName: String {
        switch self {
        case .mods:
            return "mods"
        case .resourcePacks:
            return "resourcepacks"
        case .shaderPacks:
            return "shaderpacks"
        }
    }
}

struct ManagedAsset: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let url: URL
    let isEnabled: Bool
    let conflictMessage: String?
    let metadata: ManagedAssetMetadata
    let fileSizeBytes: Int64
    let modifiedAt: Date?
    let source: String?
    let projectURL: URL?
}

struct ManagedAssetMetadata: Codable, Equatable, Sendable {
    let displayName: String?
    let version: String?
    let authors: [String]
    let summary: String?
    let iconPath: String?
    let loaders: [String]

    static let empty = ManagedAssetMetadata(
        displayName: nil,
        version: nil,
        authors: [],
        summary: nil,
        iconPath: nil,
        loaders: []
    )
}

enum VersionUsageFilter: String, CaseIterable, Identifiable {
    case all
    case installed
    case usedByInstance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .installed: return "Installed"
        case .usedByInstance: return "Used by Config"
        }
    }
}

enum ManagedAssetSort: String, CaseIterable, Identifiable {
    case name
    case status
    case source
    case updated
    case size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Name"
        case .status: return "Status"
        case .source: return "Source"
        case .updated: return "Updated"
        case .size: return "Size"
        }
    }
}

struct AssetManualLink: Codable, Equatable {
    var source: String
    var projectURL: URL?
}

enum VersionContentStoreError: LocalizedError {
    case missingInstanceGameDirectory
    case coreBackendUnavailable

    var errorDescription: String? {
        switch self {
        case .missingInstanceGameDirectory:
            return "Select a game configuration with a game directory before managing content."
        case .coreBackendUnavailable:
            return "Core backend is not ready for local content."
        }
    }
}
