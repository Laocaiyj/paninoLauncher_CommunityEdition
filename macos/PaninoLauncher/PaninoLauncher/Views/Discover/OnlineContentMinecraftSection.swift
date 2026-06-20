import SwiftUI

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
