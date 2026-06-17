import SwiftUI

enum OnlineProjectDetailPresentation {
    case full
    case inspector
}

struct OnlineProjectDetailPanel: View {
    var presentation: OnlineProjectDetailPresentation = .full
    let project: OnlineProject
    let releases: [OnlineRelease]
    @Binding var selectedReleaseID: String?
    let currentMinecraftVersion: String?
    let targetResolution: CoreContentResolveTargetsResponse?
    @Binding var selectedTargetID: String?
    let targetFailure: String?
    let projectFailure: String?
    let isLoading: Bool
    let retryLoad: () -> Void
    let install: (CoreContentTargetCandidate?) -> Void
    let openTasks: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    private var compatibleReleases: [OnlineRelease] {
        guard let currentMinecraftVersion else { return [] }
        return releases.filter { $0.gameVersions.contains(currentMinecraftVersion) }
    }

    private var selectedRelease: OnlineRelease? {
        if let selectedReleaseID,
           let release = compatibleReleases.first(where: { $0.id == selectedReleaseID }) {
            return release
        }
        return compatibleReleases.first
    }

    var body: some View {
        switch presentation {
        case .full:
            fullDetail
        case .inspector:
            inspectorDetail
        }
    }

    private var fullDetail: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 20) {
                ProjectImmersiveHeader(project: project, presentation: .full)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        contentColumn
                            .frame(minWidth: 520, maxWidth: .infinity, alignment: .topLeading)
                        actionColumn
                            .frame(width: 340, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        contentColumn
                        actionColumn
                    }
                }
            }
        }
        .frame(maxWidth: 1_260, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var inspectorDetail: some View {
        GlassPanel(showsShadow: false, surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 14) {
                ProjectImmersiveHeader(project: project, presentation: .inspector)

                actionColumn

                releasePickerSection

                ProjectDescriptionSection(text: project.description ?? project.summary, collapsedLineLimit: 6)

                Divider()

                ProjectMetadataSection(project: project, presentation: .inspector)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProjectDescriptionSection(text: project.description ?? project.summary, collapsedLineLimit: 7)
            ProjectMetadataSection(project: project, presentation: .full)
            releasePickerSection
        }
    }

    @ViewBuilder
    private var releasePickerSection: some View {
        if currentMinecraftVersion != nil || projectFailure != nil || isLoading {
            Divider()
            ReleasePickerSection(
                releases: releases,
                selectedReleaseID: $selectedReleaseID,
                currentMinecraftVersion: currentMinecraftVersion,
                projectFailure: projectFailure,
                isLoading: isLoading,
                retryLoad: retryLoad
            )
        }
    }

    @ViewBuilder
    private var actionColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            actionSection
            if let selectedRelease, project.projectType.managedAssetKind != nil {
                Divider()
                ReleaseFileDetailsSection(release: selectedRelease)
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if let selectedRelease, project.projectType.managedAssetKind != nil {
            InstallTargetSection(
                release: selectedRelease,
                currentMinecraftVersion: currentMinecraftVersion,
                targetResolution: targetResolution,
                selectedTargetID: $selectedTargetID,
                targetFailure: targetFailure,
                install: install,
                openTasks: openTasks
            )
        } else if project.projectType == .modpack {
            OnlineUnsupportedInstallFlowView(
                title: localizedString(theme.language, english: "Modpack import flow", chinese: "整合包导入流程", italian: "Importazione modpack", french: "Import modpack", spanish: "Importar modpack"),
                message: localizedString(theme.language, english: "Modpacks create or import a dedicated local instance. That flow is separate from installing single content files into an existing instance.", chinese: "整合包会创建或导入专用本地实例，不会直接写入已有普通实例。", italian: "I modpack creano o importano un'istanza dedicata.", french: "Les modpacks créent ou importent une instance dédiée.", spanish: "Los modpacks crean una instancia dedicada.")
            )
        } else {
            OnlineUnsupportedInstallFlowView(
                title: localizedString(theme.language, english: "Choose a Minecraft version", chinese: "选择 Minecraft 版本", italian: "Scegli una versione Minecraft", french: "Choisir une version Minecraft", spanish: "Elige una versión de Minecraft"),
                message: localizedString(theme.language, english: "Select a Minecraft release filter above to load installable files and compatible local targets.", chinese: "请先在上方选择 Minecraft 正式版过滤器，以加载可安装文件和兼容本地目标。", italian: "Seleziona un filtro Minecraft per caricare file e destinazioni.", french: "Sélectionnez une version Minecraft pour charger les fichiers et cibles.", spanish: "Selecciona una versión de Minecraft para cargar archivos y destinos.")
            )
        }
    }
}

private struct ProjectImmersiveHeader: View {
    let project: OnlineProject
    var presentation: OnlineProjectDetailPresentation = .full

    @State private var selectedImageIndex = 0
    @EnvironmentObject private var theme: ThemeSettings

    private var heroHeight: CGFloat {
        presentation == .inspector ? 228 : 330
    }

    private var iconSize: CGFloat {
        presentation == .inspector ? 50 : 68
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroMedia

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.44),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                headerChrome
                Spacer(minLength: 18)
                bottomContent
            }
            .padding(presentation == .inspector ? 16 : 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.panel, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(presentation == .inspector ? 0.12 : 0.20), radius: presentation == .inspector ? 18 : 28, x: 0, y: presentation == .inspector ? 8 : 14)
        .onChange(of: project.id) { _, _ in
            selectedImageIndex = 0
        }
        .onChange(of: project.galleryURLs) { _, galleryURLs in
            guard selectedImageIndex >= galleryURLs.count else { return }
            selectedImageIndex = 0
        }
        .accessibilityElement(children: .contain)
    }

    private var headerChrome: some View {
        HStack(alignment: .top, spacing: 10) {
            projectPills
            Spacer(minLength: 12)
            projectLink
        }
    }

    private var bottomContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 18) {
                titleCluster
                Spacer(minLength: 18)
                thumbnailRail
            }

            VStack(alignment: .leading, spacing: 12) {
                titleCluster
                thumbnailRail
            }
        }
    }

    private var titleCluster: some View {
        HStack(alignment: .bottom, spacing: presentation == .inspector ? 11 : 15) {
            OnlineProjectIcon(url: project.iconURL)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: presentation == .inspector ? 4 : 6) {
                Text(project.title)
                    .font(presentation == .inspector ? .title3.bold() : .largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

                Text(projectSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(project.summary)
                    .font(presentation == .inspector ? .caption : .callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(presentation == .inspector ? 2 : 3)
                    .minimumScaleFactor(0.76)
            }
        }
        .frame(maxWidth: presentation == .inspector ? .infinity : 720, alignment: .leading)
    }

    @ViewBuilder
    private var heroMedia: some View {
        GeometryReader { proxy in
            if let selectedMediaURL {
                AsyncImage(url: selectedMediaURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    case .failure:
                        fallbackMedia
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    default:
                        fallbackMedia
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                    }
                }
            } else {
                fallbackMedia
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var fallbackMedia: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.semanticSelectionColor.opacity(0.72),
                    theme.semanticSelectionColor.opacity(0.34),
                    Color(nsColor: .windowBackgroundColor).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            OnlineProjectIcon(url: project.iconURL)
                .frame(width: presentation == .inspector ? 112 : 160, height: presentation == .inspector ? 112 : 160)
                .opacity(0.22)
                .blur(radius: 1.2)
                .offset(x: presentation == .inspector ? 120 : 260, y: presentation == .inspector ? -20 : -36)
        }
    }

    private var projectPills: some View {
        HStack(spacing: 8) {
            ProjectHeroPill(text: project.source.displayName)
            ProjectHeroPill(text: project.projectType.displayTitle)
        }
    }

    @ViewBuilder
    private var thumbnailRail: some View {
        if !project.galleryURLs.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(project.galleryURLs.prefix(4).enumerated()), id: \.element) { index, url in
                    Button {
                        selectedImageIndex = index
                    } label: {
                        ProjectHeroThumbnail(url: url, isSelected: index == selectedImageIndex)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Image \(index + 1)")
                }
            }
            .padding(6)
            .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var projectLink: some View {
        if let projectURL = project.projectURL {
            Link(destination: projectURL) {
                if presentation == .inspector {
                    projectLinkLabel
                        .labelStyle(.iconOnly)
                } else {
                    projectLinkLabel
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, presentation == .inspector ? 10 : 12)
            .frame(height: 34)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private var projectLinkLabel: some View {
        Label(
            localizedString(theme.language, english: "Open Page", chinese: "打开页面", italian: "Apri pagina", french: "Ouvrir la page", spanish: "Abrir página"),
            systemImage: "safari"
        )
    }

    private var selectedMediaURL: URL? {
        guard !project.galleryURLs.isEmpty else { return nil }
        return project.galleryURLs[min(selectedImageIndex, project.galleryURLs.count - 1)]
    }

    private var projectSubtitle: String {
        [
            project.authors.prefix(2).joined(separator: ", "),
            project.source.displayName,
            project.projectType.displayTitle
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}

private struct ProjectHeroPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(.black.opacity(0.24), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
    }
}

private struct ProjectHeroThumbnail: View {
    let url: URL
    let isSelected: Bool

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            default:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.22), lineWidth: isSelected ? 2 : 1)
        }
        .opacity(isSelected ? 1 : 0.78)
    }
}

private struct ProjectDescriptionSection: View {
    let text: String
    var collapsedLineLimit = 5
    @State private var isExpanded = false
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SafeDescriptionText(text: text, lineLimit: canToggle ? (isExpanded ? nil : collapsedLineLimit) : nil)

            if canToggle {
                Button {
                    withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(
                        isExpanded
                            ? localizedString(theme.language, english: "Collapse", chinese: "收起", italian: "Comprimi", french: "Réduire", spanish: "Contraer")
                            : localizedString(theme.language, english: "Show More", chinese: "展开", italian: "Mostra altro", french: "Afficher plus", spanish: "Mostrar más"),
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.semanticSelectionColor)
            }
        }
    }

    private var canToggle: Bool {
        text.count > 280 || text.components(separatedBy: .newlines).count > 5
    }
}

private struct ProjectMetadataSection: View {
    let project: OnlineProject
    var presentation: OnlineProjectDetailPresentation = .full
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if presentation == .inspector {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 8) {
                    metadataItems
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        metadataRow(authorTitle, project.authors.prefix(3).joined(separator: ", "))
                        metadataRow(sourceTitle, project.source.displayName)
                    }
                    GridRow {
                        metadataRow(versionTitle, summarized(project.gameVersions, limit: 4))
                        metadataRow("Loader", summarized(project.loaders.map(\.displayTitle), limit: 4))
                    }
                    GridRow {
                        metadataRow(sideTitle, "\(project.clientSide.sideTitle(prefix: "Client")) · \(project.serverSide.sideTitle(prefix: "Server"))")
                        metadataRow(downloadTitle, formattedCount(project.downloads))
                    }
                    GridRow {
                        metadataRow(updatedTitle, project.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                        metadataRow(licenseTitle, project.license ?? "-")
                    }
                }
            }

            if !project.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(project.categories.prefix(10), id: \.self) { category in
                            Text(category)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.38), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var metadataItems: some View {
        metadataRow(authorTitle, project.authors.prefix(3).joined(separator: ", "))
        metadataRow(sourceTitle, project.source.displayName)
        metadataRow(versionTitle, summarized(project.gameVersions, limit: 3))
        metadataRow("Loader", summarized(project.loaders.map(\.displayTitle), limit: 3))
        metadataRow(sideTitle, "\(project.clientSide.sideTitle(prefix: "Client")) · \(project.serverSide.sideTitle(prefix: "Server"))")
        metadataRow(downloadTitle, formattedCount(project.downloads))
        metadataRow(updatedTitle, project.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
        metadataRow(licenseTitle, project.license ?? "-")
    }

    private var authorTitle: String {
        localizedString(theme.language, english: "Authors", chinese: "作者", italian: "Autori", french: "Auteurs", spanish: "Autores")
    }

    private var sourceTitle: String {
        localizedString(theme.language, english: "Source", chinese: "来源", italian: "Fonte", french: "Source", spanish: "Fuente")
    }

    private var versionTitle: String {
        localizedString(theme.language, english: "Versions", chinese: "版本", italian: "Versioni", french: "Versions", spanish: "Versiones")
    }

    private var sideTitle: String {
        localizedString(theme.language, english: "Side", chinese: "运行端", italian: "Lato", french: "Côté", spanish: "Lado")
    }

    private var downloadTitle: String {
        localizedString(theme.language, english: "Downloads", chinese: "下载量", italian: "Download", french: "Téléchargements", spanish: "Descargas")
    }

    private var updatedTitle: String {
        localizedString(theme.language, english: "Updated", chinese: "更新", italian: "Aggiornato", french: "Mis à jour", spanish: "Actualizado")
    }

    private var licenseTitle: String {
        localizedString(theme.language, english: "License", chinese: "许可证", italian: "Licenza", french: "Licence", spanish: "Licencia")
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value.isEmpty ? "-" : value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summarized(_ values: [String], limit: Int) -> String {
        let cleaned = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !cleaned.isEmpty else { return "-" }
        let prefix = cleaned.prefix(limit).joined(separator: ", ")
        if cleaned.count > limit {
            return "\(prefix) +\(cleaned.count - limit)"
        }
        return prefix
    }

    private func formattedCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

private struct ReleasePickerSection: View {
    let releases: [OnlineRelease]
    @Binding var selectedReleaseID: String?
    let currentMinecraftVersion: String?
    let projectFailure: String?
    let isLoading: Bool
    let retryLoad: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAll = false

    private var compatibleReleases: [OnlineRelease] {
        guard let currentMinecraftVersion else { return [] }
        return releases.filter { $0.gameVersions.contains(currentMinecraftVersion) }
    }

    private var visibleReleases: [OnlineRelease] {
        showAll ? compatibleReleases : Array(compatibleReleases.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizedString(theme.language, english: "Choose Version", chinese: "选择版本", italian: "Scegli versione", french: "Choisir version", spanish: "Elegir versión"))
                    .font(.headline)
                Spacer()
                CountText(value: compatibleReleases.count)
            }

            if let projectFailure {
                HStack(spacing: 8) {
                    Label(localizedOnlineError(projectFailure, language: theme.language), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: retryLoad)
                }
            } else if currentMinecraftVersion == nil {
                Label(localizedString(theme.language, english: "Select a Minecraft release to filter installable versions.", chinese: "请选择 Minecraft 正式版，以筛选可安装版本。", italian: "Seleziona una release Minecraft per filtrare.", french: "Sélectionnez une version Minecraft pour filtrer.", spanish: "Selecciona una versión de Minecraft para filtrar."), systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isLoading && releases.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localizedString(theme.language, english: "Loading compatible files...", chinese: "正在加载兼容文件...", italian: "Caricamento file compatibili...", french: "Chargement des fichiers compatibles...", spanish: "Cargando archivos compatibles..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if compatibleReleases.isEmpty {
                ContentUnavailableView(
                    localizedString(theme.language, english: "No compatible release", chinese: "没有兼容版本", italian: "Nessuna versione compatibile", french: "Aucune version compatible", spanish: "Sin versión compatible"),
                    systemImage: "tray",
                    description: Text(localizedString(theme.language, english: "This project did not return files for the selected Minecraft version.", chinese: "该项目没有返回当前 Minecraft 版本可用的文件。", italian: "Nessun file per la versione Minecraft selezionata.", french: "Aucun fichier pour la version Minecraft choisie.", spanish: "No hay archivos para la versión de Minecraft seleccionada."))
                )
                .frame(minHeight: 120)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(visibleReleases) { release in
                        ReleasePickerRow(
                            release: release,
                            selected: isSelected(release)
                        ) {
                            selectedReleaseID = release.id
                        }
                    }
                }

                if compatibleReleases.count > 10 {
                    Button {
                        withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                            showAll.toggle()
                        }
                    } label: {
                        Label(showMoreTitle, systemImage: showAll ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.semanticSelectionColor)
                }
            }
        }
    }

    private var showMoreTitle: String {
        if showAll {
            return localizedString(theme.language, english: "Show Less", chinese: "收起", italian: "Mostra meno", french: "Afficher moins", spanish: "Mostrar menos")
        }
        let remaining = compatibleReleases.count - visibleReleases.count
        return localizedString(theme.language, english: "Show \(remaining) More", chinese: "显示更多 \(remaining) 个", italian: "Mostra altri \(remaining)", french: "Afficher \(remaining) de plus", spanish: "Mostrar \(remaining) más")
    }

    private func isSelected(_ release: OnlineRelease) -> Bool {
        (selectedReleaseID ?? compatibleReleases.first?.id) == release.id
    }
}

private struct ReleasePickerRow: View {
    let release: OnlineRelease
    let selected: Bool
    let select: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(release.versionName.isEmpty ? release.versionNumber : release.versionName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(releaseSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 10)
                PlainStatusText(title: release.releaseType.rawValue.capitalized, style: releaseBadgeStyle)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(selected ? 0.5 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var releaseSubtitle: String {
        [
            release.gameVersions.prefix(4).joined(separator: ", "),
            release.loaders.map(\.displayTitle).joined(separator: ", "),
            release.publishedAt?.formatted(date: .abbreviated, time: .omitted)
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " · ")
    }

    private var releaseBadgeStyle: StatusBadge.Style {
        switch release.releaseType {
        case .release:
            return .neutral
        case .beta, .snapshot:
            return .warning
        case .alpha, .unknown:
            return .error
        }
    }
}

private struct InstallTargetSection: View {
    let release: OnlineRelease
    let currentMinecraftVersion: String?
    let targetResolution: CoreContentResolveTargetsResponse?
    @Binding var selectedTargetID: String?
    let targetFailure: String?
    let install: (CoreContentTargetCandidate?) -> Void
    let openTasks: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAllTargets = false

    private var selectedFile: OnlineFile? {
        release.files.first(where: \.isPrimary) ?? release.files.first
    }

    private var recommendedTarget: CoreContentTargetCandidate? {
        guard let target = targetResolution?.recommended, isVersionMatched(target) else { return nil }
        return target
    }

    private var versionMatchedTargets: [CoreContentTargetCandidate] {
        guard let targetResolution else { return [] }
        var seen = Set<String>()
        var targets: [CoreContentTargetCandidate] = []
        if let recommendedTarget, seen.insert(recommendedTarget.id).inserted {
            targets.append(recommendedTarget)
        }
        for candidate in targetResolution.candidates where isVersionMatched(candidate) {
            if seen.insert(candidate.id).inserted {
                targets.append(candidate)
            }
        }
        return targets
    }

    private var selectedTarget: CoreContentTargetCandidate? {
        guard let selectedTargetID else { return nil }
        return versionMatchedTargets.first { $0.id == selectedTargetID }
    }

    private var activeTarget: CoreContentTargetCandidate? {
        selectedTarget ?? recommendedTarget
    }

    private var visibleTargets: [CoreContentTargetCandidate] {
        showAllTargets ? versionMatchedTargets : Array(versionMatchedTargets.prefix(5))
    }

    private var hiddenTargetCount: Int {
        max(versionMatchedTargets.count - visibleTargets.count, 0)
    }

    private var hasVersionMatchedTarget: Bool {
        !versionMatchedTargets.isEmpty
    }

    private var canInstall: Bool {
        selectedFile?.downloadURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizedString(theme.language, english: "Install Target", chinese: "安装目标", italian: "Destinazione installazione", french: "Cible d'installation", spanish: "Destino de instalación"))
                    .font(.headline)
                Spacer()
                if hasVersionMatchedTarget {
                    CountText(value: versionMatchedTargets.count, style: .download)
                }
            }

            if let targetFailure {
                Label(localizedOnlineError(targetFailure, language: theme.language), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            } else if targetResolution != nil {
                if versionMatchedTargets.isEmpty {
                    Label(noMatchingInstanceMessage, systemImage: "tray")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleTargets) { target in
                            Button {
                                selectedTargetID = target.id
                            } label: {
                                TargetCandidateRow(
                                    target: target,
                                    selected: target.id == activeTarget?.id,
                                    recommended: target.id == recommendedTarget?.id
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if versionMatchedTargets.count > 5 {
                            Button {
                                withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                                    showAllTargets.toggle()
                                }
                            } label: {
                                Label(showMoreTargetsTitle, systemImage: showAllTargets ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.semanticSelectionColor)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localizedString(theme.language, english: "Matching local instances...", chinese: "正在匹配本地实例...", italian: "Ricerca istanze locali...", french: "Recherche des instances locales...", spanish: "Buscando instancias locales..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlassButton(systemImage: primaryButtonIcon, title: primaryButtonTitle, prominent: true) {
                        install(activeTarget)
                    }
                        .disabled(!canInstall)
                    GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas"), action: openTasks)
                }

                if !canInstall {
                    Text(localizedString(theme.language, english: "Missing downloadable file for the selected release.", chinese: "所选版本缺少可下载文件。", italian: "File scaricabile mancante.", french: "Fichier téléchargeable manquant.", spanish: "Falta archivo descargable."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var showMoreTargetsTitle: String {
        if showAllTargets {
            return localizedString(theme.language, english: "Show Fewer Targets", chinese: "收起匹配实例", italian: "Mostra meno destinazioni", french: "Afficher moins de cibles", spanish: "Mostrar menos destinos")
        }
        return localizedString(theme.language, english: "\(hiddenTargetCount) more matching targets", chinese: "还有 \(hiddenTargetCount) 个匹配实例", italian: "Altre \(hiddenTargetCount) destinazioni", french: "\(hiddenTargetCount) autres cibles", spanish: "\(hiddenTargetCount) destinos más")
    }

    private var primaryButtonTitle: String {
        if activeTarget != nil {
            return localizedString(theme.language, english: "Install to Selected Instance", chinese: "安装到所选实例", italian: "Installa nell'istanza selezionata", french: "Installer dans l'instance choisie", spanish: "Instalar en instancia seleccionada")
        }
        return localizedString(theme.language, english: "Choose Folder and Install", chinese: "选择文件夹并安装", italian: "Scegli cartella e installa", french: "Choisir dossier et installer", spanish: "Elegir carpeta e instalar")
    }

    private var primaryButtonIcon: String {
        activeTarget == nil ? "folder.badge.gearshape" : "arrow.down.circle"
    }

    private var noMatchingInstanceMessage: String {
        let version = currentMinecraftVersion ?? release.gameVersions.first ?? "-"
        return localizedString(
            theme.language,
            english: "No local instance matches Minecraft \(version).",
            chinese: "没有匹配 Minecraft \(version) 的本地实例。",
            italian: "Nessuna istanza locale per Minecraft \(version).",
            french: "Aucune instance locale pour Minecraft \(version).",
            spanish: "No hay instancia local para Minecraft \(version)."
        )
    }

    private func isVersionMatched(_ target: CoreContentTargetCandidate) -> Bool {
        let hasVersionMismatch = target.blockedReasons.contains { reason in
            reason.localizedCaseInsensitiveContains("minecraft_version_mismatch")
        }
        guard !hasVersionMismatch else { return false }
        return release.gameVersions.isEmpty || release.gameVersions.contains(target.minecraftVersion)
    }
}

private struct TargetCandidateRow: View {
    let target: CoreContentTargetCandidate
    let selected: Bool
    let recommended: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(target.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                PlainStatusText(title: statusTitle, style: statusStyle)
            }
            Text([
                "Minecraft \(target.minecraftVersion)",
                target.loader.map { loaderTitle($0) }
            ].compactMap { $0 }.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            if let reasonSummary {
                Text(reasonSummary)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(selected ? 0.46 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? theme.semanticSelectionColor.opacity(0.7) : Color(nsColor: .separatorColor).opacity(0.28), lineWidth: selected ? 1.5 : 1)
        }
        .help(target.gameDir)
    }

    private var statusTitle: String {
        if target.blockedReasons.isEmpty {
            return selected
                ? localizedString(theme.language, english: "Selected", chinese: "已选择", italian: "Selezionata", french: "Sélectionnée", spanish: "Seleccionada")
                : recommended
                ? localizedString(theme.language, english: "Recommended", chinese: "推荐", italian: "Consigliata", french: "Recommandée", spanish: "Recomendada")
                : localizedString(theme.language, english: "Matched", chinese: "匹配", italian: "Compatibile", french: "Compatible", spanish: "Compatible")
        }
        return localizedString(theme.language, english: "Review", chinese: "需确认", italian: "Verifica", french: "À vérifier", spanish: "Revisar")
    }

    private var statusStyle: StatusBadge.Style {
        target.blockedReasons.isEmpty ? .success : .warning
    }

    private var reasonSummary: String? {
        let reasons = target.blockedReasons.filter { !$0.localizedCaseInsensitiveContains("minecraft_version_mismatch") }
        guard !reasons.isEmpty else { return nil }
        return reasons.joined(separator: ", ")
    }

    private func loaderTitle(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "fabric": return "Fabric"
        case "quilt": return "Quilt"
        case "forge": return "Forge"
        case "neoforge": return "NeoForge"
        default: return rawValue
        }
    }
}

private struct ReleaseFileDetailsSection: View {
    let release: OnlineRelease

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isExpanded = true

    private var primaryFile: OnlineFile? {
        release.files.first(where: \.isPrimary) ?? release.files.first
    }

    var body: some View {
        FullWidthDisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 7) {
                if let primaryFile {
                    metadataRow("File", primaryFile.fileName)
                    metadataRow("Size", formattedBytes(primaryFile.sizeBytes))
                    ForEach(primaryFile.hashes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        metadataRow(key.uppercased(), value)
                    }
                }
                metadataRow("Release", release.releaseType.rawValue.capitalized)
                metadataRow("Game", release.gameVersions.prefix(6).joined(separator: ", "))
                metadataRow("Loader", release.loaders.map(\.displayTitle).joined(separator: ", "))

                if !release.dependencies.isEmpty {
                    Text(localizedString(theme.language, english: "Dependencies", chinese: "依赖", italian: "Dipendenze", french: "Dépendances", spanish: "Dependencias"))
                        .font(.caption.weight(.semibold))
                    ForEach(release.dependencies.prefix(8)) { dependency in
                        Text("\(dependency.relation.rawValue): \(dependency.projectID ?? dependency.versionID ?? dependency.id)")
                            .font(.caption)
                            .foregroundStyle(dependency.relation == .incompatible ? .orange : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let changelog = release.changelog, !changelog.isEmpty {
                    Text(localizedString(theme.language, english: "Changelog", chinese: "更新日志", italian: "Registro modifiche", french: "Journal des modifications", spanish: "Cambios"))
                        .font(.caption.weight(.semibold))
                    SafeDescriptionText(text: changelog, lineLimit: 8)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(localizedString(theme.language, english: "File Details", chinese: "文件详情", italian: "Dettagli file", french: "Détails du fichier", spanish: "Detalles del archivo"))
                    .font(.headline)
                Spacer()
                if let primaryFile {
                    Text(formattedBytes(primaryFile.sizeBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

private struct OnlineUnsupportedInstallFlowView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SafeDescriptionText: View {
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
