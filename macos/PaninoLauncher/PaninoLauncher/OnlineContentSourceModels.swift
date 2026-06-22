import Foundation

enum ContentSourceID: String, Codable, CaseIterable, Identifiable, Sendable {
    case modrinth
    case curseForge
    case mojang
    case fabric
    case quilt
    case forge
    case neoForge
    case github
    case hangar
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modrinth: return "Modrinth"
        case .curseForge: return "CurseForge"
        case .mojang: return "Mojang/Piston Meta"
        case .fabric: return "Fabric Meta"
        case .quilt: return "Quilt Meta"
        case .forge: return "Forge"
        case .neoForge: return "NeoForge"
        case .github: return "GitHub Releases"
        case .hangar: return "Hangar"
        case .custom: return "Custom"
        }
    }
}

enum OnlineProjectType: String, Codable, CaseIterable, Identifiable, Sendable {
    case mod
    case modpack
    case resourcePack
    case shaderPack
    case plugin
    case minecraftVersion
    case loader

    var id: String { rawValue }
}

enum OnlineSideSupport: String, Codable, Sendable {
    case required
    case optional
    case unsupported
    case unknown
}

enum LoaderFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case fabric
    case quilt
    case forge
    case neoForge

    var id: String { rawValue }
}

enum OnlineContentSort: String, Codable, CaseIterable, Sendable {
    case relevance
    case downloads
    case updated
    case newest
    case follows
}
