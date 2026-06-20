import Foundation

enum LoaderKind: String, Codable, CaseIterable, Identifiable {
    case fabric
    case quilt
    case forge
    case neoForge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fabric:
            return "Fabric"
        case .quilt:
            return "Quilt"
        case .forge:
            return "Forge"
        case .neoForge:
            return "NeoForge"
        }
    }

    var contentSourceID: ContentSourceID {
        switch self {
        case .fabric:
            return .fabric
        case .quilt:
            return .quilt
        case .forge:
            return .forge
        case .neoForge:
            return .neoForge
        }
    }
}

struct LoaderCompatibilityOption: Identifiable, Equatable {
    let kind: LoaderKind
    let recommendedVersion: String?
    let versions: [LoaderMetadata]
    let isAvailable: Bool
    let reason: String?

    var id: LoaderKind { kind }

    static func options(from response: CoreLoaderCompatibilityResponse) -> [LoaderCompatibilityOption] {
        LoaderKind.allCases.map { kind in
            guard let entry = response.options.first(where: { $0.loader == kind.rawValue }) else {
                return LoaderCompatibilityOption(
                    kind: kind,
                    recommendedVersion: nil,
                    versions: [],
                    isAvailable: false,
                    reason: "Core did not report \(kind.title) compatibility for this Minecraft version."
                )
            }
            let versions = entry.versions.map { version in
                LoaderMetadata(
                    id: "\(kind.rawValue)-\(response.minecraftVersion)-\(version)",
                    source: kind.contentSourceID,
                    minecraftVersion: response.minecraftVersion,
                    loaderVersion: version,
                    installerVersion: nil,
                    stable: !entry.experimental || version == entry.recommendedVersion,
                    downloadURL: nil
                )
            }
            return LoaderCompatibilityOption(
                kind: kind,
                recommendedVersion: entry.recommendedVersion,
                versions: versions,
                isAvailable: entry.available,
                reason: entry.reason
            )
        }
    }

    static func options(from metadata: [LoaderMetadata]) -> [LoaderCompatibilityOption] {
        let grouped = Dictionary(grouping: metadata) { item in
            item.source.loaderKind
        }
        return LoaderKind.allCases.map { kind in
            let versions = (grouped[kind] ?? [])
                .sorted { lhs, rhs in
                    if lhs.stable != rhs.stable { return lhs.stable && !rhs.stable }
                    return lhs.loaderVersion.localizedStandardCompare(rhs.loaderVersion) == .orderedDescending
                }
            return LoaderCompatibilityOption(
                kind: kind,
                recommendedVersion: versions.first(where: \.stable)?.loaderVersion ?? versions.first?.loaderVersion,
                versions: versions,
                isAvailable: !versions.isEmpty,
                reason: versions.isEmpty ? "Core did not report a compatible \(kind.title) build for this Minecraft version." : nil
            )
        }
    }
}

struct GameConfigurationCapabilities: Equatable {
    let canLaunch: Bool
    let canManageMods: Bool
    let canManageResourcePacks: Bool
    let canManageShaderPacks: Bool
    let canInstallLoader: Bool
    let canExportModpack: Bool
    let canBackupSaves: Bool
    let canRepair: Bool

    static func capabilities(for instance: GameInstance) -> GameConfigurationCapabilities {
        let hasLoader = instance.loader != nil
        return GameConfigurationCapabilities(
            canLaunch: instance.status != .installing,
            canManageMods: hasLoader,
            canManageResourcePacks: true,
            canManageShaderPacks: hasLoader,
            canInstallLoader: instance.loader == nil,
            canExportModpack: hasLoader,
            canBackupSaves: true,
            canRepair: instance.status == .notInstalled || instance.status == .failed
        )
    }
}

extension ContentSourceID {
    var loaderKind: LoaderKind? {
        switch self {
        case .fabric:
            return .fabric
        case .quilt:
            return .quilt
        case .forge:
            return .forge
        case .neoForge:
            return .neoForge
        default:
            return nil
        }
    }
}
