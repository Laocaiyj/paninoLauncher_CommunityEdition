import SwiftUI

struct SafeDescriptionText: View {
    let text: String
    var lineLimit: Int?

    var body: some View {
        if let attributed = try? AttributedString(markdown: sanitizedMarkdown(text)) {
            styled(Text(attributed))
        } else {
            styled(Text(sanitizedMarkdown(text)))
        }
    }

    private func styled(_ text: Text) -> some View {
        text
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(lineLimit)
            .textSelection(.enabled)
    }
}

extension LoaderFamily {
    var displayTitle: String {
        switch self {
        case .fabric: return "Fabric"
        case .quilt: return "Quilt"
        case .forge: return "Forge"
        case .neoForge: return "NeoForge"
        }
    }
}

extension OnlineProjectType {
    var managedAssetKind: ManagedAssetKind? {
        switch self {
        case .mod:
            return .mods
        case .resourcePack:
            return .resourcePacks
        case .shaderPack:
            return .shaderPacks
        case .modpack, .plugin, .minecraftVersion, .loader:
            return nil
        }
    }
}

extension OnlineContentSort {
    func title(language: AppLanguage) -> String {
        switch self {
        case .relevance:
            return localizedString(language, english: "Relevance", chinese: "相关度", italian: "Rilevanza", french: "Pertinence", spanish: "Relevancia")
        case .downloads:
            return localizedString(language, english: "Downloads", chinese: "下载量", italian: "Download", french: "Téléchargements", spanish: "Descargas")
        case .updated:
            return localizedString(language, english: "Updated", chinese: "更新时间", italian: "Aggiornati", french: "Mis à jour", spanish: "Actualizados")
        case .newest:
            return localizedString(language, english: "Newest", chinese: "最新发布", italian: "Più recenti", french: "Nouveautés", spanish: "Más recientes")
        case .follows:
            return localizedString(language, english: "Follows", chinese: "关注数", italian: "Seguiti", french: "Suivis", spanish: "Seguidores")
        }
    }
}

extension OnlineSideSupport {
    var badgeStyle: StatusBadge.Style {
        switch self {
        case .required:
            return .success
        case .optional:
            return .download
        case .unsupported:
            return .warning
        case .unknown:
            return .neutral
        }
    }

    func sideTitle(prefix: String) -> String {
        switch self {
        case .required:
            return "\(prefix) required"
        case .optional:
            return "\(prefix) optional"
        case .unsupported:
            return "\(prefix) unsupported"
        case .unknown:
            return "\(prefix) unknown"
        }
    }
}
