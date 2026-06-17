import AppKit
import SwiftUI

enum DiscoverSection: String, CaseIterable, Identifiable {
    case minecraft
    case mods
    case modpacks
    case resources
    case shaders

    var id: String { rawValue }

    var projectType: OnlineProjectType? {
        switch self {
        case .minecraft:
            return nil
        case .mods:
            return .mod
        case .modpacks:
            return .modpack
        case .resources:
            return .resourcePack
        case .shaders:
            return .shaderPack
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .minecraft:
            return "Minecraft"
        case .mods:
            return "Mods"
        case .modpacks:
            return "Modpacks"
        case .resources:
            return localizedString(language, english: "Resource Packs", chinese: "资源包", italian: "Pacchetti risorse", french: "Packs de ressources", spanish: "Paquetes de recursos")
        case .shaders:
            return localizedString(language, english: "Shaders", chinese: "光影包", italian: "Shader", french: "Shaders", spanish: "Shaders")
        }
    }

}

struct PendingContentInstallReview: Identifiable {
    let id = UUID()
    let plan: CoreContentInstallPlanResponse
    let releaseVersionName: String
    let request: CoreContentInstallRequest
    let managedKind: ManagedAssetKind
}

struct MinecraftVersionBrowsePage: View {
    let versions: [MinecraftVersionInfo]
    let latestReleaseID: String?
    let latestSnapshotID: String?
    let status: String
    @Binding var searchText: String
    @Binding var group: MinecraftBrowseGroup
    @Binding var page: Int
    let refresh: () -> Void
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    private let pageSize = 12

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    HStack {
                        PanelHeader(
                            title: localizedString(theme.language, english: "Minecraft Downloads", chinese: "Minecraft 下载", italian: "Download Minecraft", french: "Téléchargements Minecraft", spanish: "Descargas de Minecraft"),
                            systemImage: "cube.box"
                        )
                        Spacer()
                        CountText(value: versions.count, style: .download)
                        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refresh)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                        ForEach(latestVersions) { version in
                            MinecraftVersionFeatureCard(version: version, select: select)
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    HStack(spacing: 10) {
                        PaninoTextInput(
                            localizedString(theme.language, english: "Search version, e.g. 1.20.1 or 1.7.10", chinese: "搜索版本，例如 1.20.1 或 1.7.10", italian: "Cerca versione, es. 1.20.1", french: "Rechercher version, ex. 1.20.1", spanish: "Buscar versión, ej. 1.20.1"),
                            text: $searchText
                        )
                        PaninoGlassSegmentedRail {
                            Picker("", selection: $group) {
                                ForEach(MinecraftBrowseGroup.allCases) { browseGroup in
                                    Text(browseGroup.title(language: theme.language)).tag(browseGroup)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(minWidth: 300, idealWidth: 430, maxWidth: 500)
                        }
                    }

                    HStack {
                        Text(group.title(language: theme.language))
                            .font(.headline)
                        Spacer()
                        CountText(value: filteredVersions.count)
                    }

                    if pagedVersions.isEmpty {
                        ContentUnavailableView(
                            localizedString(theme.language, english: "No versions found", chinese: "未找到版本", italian: "Nessuna versione", french: "Aucune version", spanish: "Sin versiones"),
                            systemImage: "tray",
                            description: Text(status)
                        )
                        .frame(minHeight: 150)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                            ForEach(pagedVersions) { version in
                                MinecraftVersionBrowseCard(version: version, select: select)
                            }
                        }
                    }

                    HStack {
                        Text(pageStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Previous", chinese: "上一页", italian: "Precedente", french: "Précédent", spanish: "Anterior")) {
                            page = max(page - 1, 0)
                        }
                        .disabled(page <= 0)
                        GlassButton(systemImage: "chevron.right", title: localizedString(theme.language, english: "Next", chinese: "下一页", italian: "Successiva", french: "Suivant", spanish: "Siguiente")) {
                            page = min(page + 1, maxPage)
                        }
                        .disabled(page >= maxPage)
                    }
                }
            }
        }
    }

    private var latestVersions: [MinecraftVersionInfo] {
        uniqueVersions(
            [latestReleaseID, latestSnapshotID]
                .compactMap { id in id.flatMap { versionID in versions.first { $0.id == versionID } } }
        )
    }

    private var groupVersions: [MinecraftVersionInfo] {
        switch group {
        case .recommended:
            return uniqueVersions(
                latestVersions
                    + Array(versions.filter { $0.kind == .release }.prefix(10))
            )
        case .release:
            return versions.filter { $0.kind == .release }
        case .snapshot:
            return versions.filter { $0.kind == .snapshot }
        case .historical:
            return versions.filter { $0.kind == .oldBeta || $0.kind == .oldAlpha }
        }
    }

    private var filteredVersions: [MinecraftVersionInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty ? groupVersions : versions
        let filtered = query.isEmpty ? base : base.filter { $0.id.localizedCaseInsensitiveContains(query) }
        return filtered.sorted { lhs, rhs in
            if !query.isEmpty {
                let lowerQuery = query.lowercased()
                let lhsExact = lhs.id.caseInsensitiveCompare(query) == .orderedSame
                let rhsExact = rhs.id.caseInsensitiveCompare(query) == .orderedSame
                if lhsExact != rhsExact { return lhsExact && !rhsExact }
                let lhsPrefix = lhs.id.lowercased().hasPrefix(lowerQuery)
                let rhsPrefix = rhs.id.lowercased().hasPrefix(lowerQuery)
                if lhsPrefix != rhsPrefix { return lhsPrefix && !rhsPrefix }
            }
            if group != .recommended || !query.isEmpty {
                if lhs.isUsedByInstance != rhs.isUsedByInstance {
                    return lhs.isUsedByInstance && !rhs.isUsedByInstance
                }
                if lhs.isInstalled != rhs.isInstalled {
                    return lhs.isInstalled && !rhs.isInstalled
                }
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedDescending
        }
    }

    private var pagedVersions: [MinecraftVersionInfo] {
        let start = min(currentPage * pageSize, filteredVersions.count)
        let end = min(start + pageSize, filteredVersions.count)
        guard start < end else { return [] }
        return Array(filteredVersions[start..<end])
    }

    private var maxPage: Int {
        max(Int(ceil(Double(filteredVersions.count) / Double(pageSize))) - 1, 0)
    }

    private var currentPage: Int {
        min(max(page, 0), maxPage)
    }

    private var pageStatus: String {
        guard !filteredVersions.isEmpty else { return status }
        let start = currentPage * pageSize + 1
        let end = min((currentPage + 1) * pageSize, filteredVersions.count)
        return localizedString(
            theme.language,
            english: "\(start)-\(end) of \(filteredVersions.count) versions",
            chinese: "第 \(start)-\(end) 个，共 \(filteredVersions.count) 个版本",
            italian: "\(start)-\(end) di \(filteredVersions.count) versioni",
            french: "\(start)-\(end) sur \(filteredVersions.count) versions",
            spanish: "\(start)-\(end) de \(filteredVersions.count) versiones"
        )
    }
}

struct MinecraftVersionFeatureCard: View {
    let version: MinecraftVersionInfo
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button {
            select(version)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    MetadataLine(items: [version.kind.title(language: theme.language)], font: .caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                Text(version.id)
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("\(version.releasedAt) · \(version.javaRequirement)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let stateText = discoverVisibleDownloadState(version, language: theme.language) {
                    Text(stateText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(theme.semanticSelectionColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.semanticSelectionColor.opacity(0.38), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MinecraftVersionBrowseCard: View {
    let version: MinecraftVersionInfo
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button {
            select(version)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(version.id)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    MetadataLine(items: [version.kind.title(language: theme.language)], font: .caption.weight(.semibold))
                }
                Text("\(version.releasedAt) · \(version.javaRequirement)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let stateText = browseStateText {
                        Text(stateText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.34), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var browseStateText: String? {
        if version.isUsedByInstance {
            return localizedString(theme.language, english: "Used by config", chinese: "配置使用中", italian: "Usata", french: "Utilisée", spanish: "En uso")
        }
        return discoverVisibleDownloadState(version, language: theme.language)
    }
}
