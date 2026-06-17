import AppKit
import SwiftUI

extension OnlineContentDiscoveryPage {
    var discoverSceneBackground: some View {
        DiscoverImmersiveBackground(section: selectedSection)
    }

    var discoverScenePrimary: some View {
        DiscoverImmersivePrimary(
            title: discoverSceneTitle,
            subtitle: discoverSceneSubtitle,
            metadata: discoverSceneMetadata,
            status: discoverSceneStatus
        )
    }

    var discoverSceneControls: some View {
        let showsSourceControls = selectedSection != .minecraft

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                discoverSectionPicker
                    .frame(
                        minWidth: showsSourceControls ? 420 : 540,
                        idealWidth: showsSourceControls ? 560 : 760,
                        maxWidth: showsSourceControls ? 720 : 960,
                        alignment: .leading
                    )
                    .layoutPriority(showsSourceControls ? 0 : 1)
                    .scaleEffect(x: showsSourceControls ? 0.985 : 1, y: 1, anchor: .leading)
                if showsSourceControls {
                    searchSourceControls
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: showsSourceControls ? 1_080 : 980, alignment: showsSourceControls ? .leading : .center)
            .animation(
                PaninoMotion.noneWhenReduced(PaninoMotion.standard, reduceMotion: reduceMotion || theme.reducesInterfaceMotion),
                value: showsSourceControls
            )

            VStack(alignment: .trailing, spacing: 8) {
                discoverSectionPicker
                if showsSourceControls {
                    searchSourceControls
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(
                PaninoMotion.noneWhenReduced(PaninoMotion.standard, reduceMotion: reduceMotion || theme.reducesInterfaceMotion),
                value: showsSourceControls
            )
        }
    }

    @ViewBuilder
    var discoverSceneContextShelf: some View {
        if selectedSection == .minecraft {
            DiscoverMinecraftSceneShelf(
                versionCount: versionStore.versions.count,
                status: versionStore.versionStatus,
                searchText: $minecraftSearchText,
                group: $minecraftBrowseGroup,
                refresh: refreshMinecraftVersions
            )
        } else {
            searchPanel
        }
    }

    private var discoverSectionPicker: some View {
        PaninoGlassSegmentedRail {
            Picker("", selection: $selectedSection) {
                ForEach(DiscoverSection.allCases) { section in
                    Text(section.title(language: theme.language)).tag(section)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
    }

    private var discoverSceneTitle: String {
        if selectedSection == .minecraft, let selectedMinecraftVersion {
            return "Minecraft \(selectedMinecraftVersion.id)"
        }
        return selectedSection.title(language: theme.language)
    }

    private var discoverSceneSubtitle: String {
        if selectedSection == .minecraft {
            return localizedString(
                theme.language,
                english: "Browse releases, snapshots, loaders, shader loaders, and local install targets.",
                chinese: "浏览正式版、快照、加载器、光影加载器和本地安装目标。",
                italian: "Sfoglia release, snapshot, loader, shader loader e destinazioni locali.",
                french: "Parcourez les versions, snapshots, chargeurs, shaders et cibles locales.",
                spanish: "Explora versiones, snapshots, loaders, shaders y destinos locales."
            )
        }
        return localizedString(
            theme.language,
            english: "Search installable content with compatibility filters and a side-by-side quick view.",
            chinese: "用兼容性筛选搜索可安装内容，并在旁侧快速查看详情。",
            italian: "Cerca contenuti installabili con filtri di compatibilita e vista rapida.",
            french: "Recherchez du contenu installable avec filtres de compatibilite et apercu.",
            spanish: "Busca contenido instalable con filtros de compatibilidad y vista rapida."
        )
    }

    private var discoverSceneMetadata: [String] {
        if selectedSection == .minecraft {
            return [
                localizedString(theme.language, english: "Versions \(versionStore.versions.count)", chinese: "\(versionStore.versions.count) 个版本", italian: "\(versionStore.versions.count) versioni", french: "\(versionStore.versions.count) versions", spanish: "\(versionStore.versions.count) versiones"),
                minecraftBrowseGroup.title(language: theme.language),
                minecraftSearchText.isEmpty ? nil : minecraftSearchText
            ].compactMap { $0 }
        }

        return [
            selectedSource.displayName,
            selectedType.displayTitle,
            selectedLoader?.displayTitle,
            useMinecraftVersionFilter ? selectedContentMinecraftVersionID.map { "Minecraft \($0)" } : nil,
            localizedString(theme.language, english: "\(projects.count) results", chinese: "\(projects.count) 个结果", italian: "\(projects.count) risultati", french: "\(projects.count) resultats", spanish: "\(projects.count) resultados")
        ].compactMap { $0 }
    }

    private var discoverSceneStatus: String {
        if selectedSection == .minecraft {
            return versionStore.versionStatus
        }
        return sourceStatusText
    }

    var discoverSectionBar: some View {
        GlassPanel(surfaceLevel: .floatingChrome) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: catalogColumns, alignment: .leading, spacing: 10) {
                    discoverCatalogButton(.minecraft)
                    discoverCatalogButton(.mods)
                    discoverCatalogButton(.modpacks)
                    discoverCatalogButton(.resources)
                    discoverCatalogButton(.shaders)
                }
            }
        }
    }

    var catalogColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148), spacing: 8, alignment: .leading)]
    }

    func discoverCatalogButton(_ section: DiscoverSection) -> some View {
        let isSelected = selectedSection == section
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion || theme.reducesInterfaceMotion
        )
        return Button {
            withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.standard, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 8) {
                Text(section.title(language: theme.language))
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.controlMinSize, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            let shape = RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
            if isSelected {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.semanticSelectionColor.opacity(0.96),
                                theme.semanticSelectionColor.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape.strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                    }
                    .shadow(
                        color: theme.semanticSelectionColor.opacity(0.24),
                        radius: tokens.shadowRadius * 0.32,
                        x: 0,
                        y: tokens.shadowYOffset * 0.24
                    )
            } else {
                shape
                    .fill(Color.clear)
                    .paninoGlassSurface(
                        tokens: tokens,
                        level: .elevatedPanel,
                        cornerRadius: tokens.controlCornerRadius,
                        interactive: true
                    )
                    .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.32))
                    .overlay(theme.semanticSelectionColor.opacity(tokens.accentBackgroundOpacity * 0.28))
                    .paninoDepthOverlay(tokens: tokens, level: .elevatedPanel, cornerRadius: tokens.controlCornerRadius)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? Color.white.opacity(0.22)
                        : tokens.strokeColor.opacity(tokens.strokeOpacity * 0.58),
                    lineWidth: tokens.strokeWidth
                )
        }
    }

    var discoverSidebar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString(theme.language, english: "Minecraft", chinese: "Minecraft", italian: "Minecraft", french: "Minecraft", spanish: "Minecraft"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                discoverSidebarButton(.minecraft)

                Divider()
                    .padding(.vertical, 4)

                Text(localizedString(theme.language, english: "Resources", chinese: "资源", italian: "Risorse", french: "Ressources", spanish: "Recursos"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                discoverSidebarButton(.mods)
                discoverSidebarButton(.modpacks)
                discoverSidebarButton(.resources)
                discoverSidebarButton(.shaders)
            }
        }
    }

    func discoverSidebarButton(_ section: DiscoverSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            Text(section.title(language: theme.language))
                .font(.callout.weight(selectedSection == section ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.controlMinSize, alignment: .leading)
                .padding(.horizontal, 10)
                .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedSection == section ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                .fill(selectedSection == section ? theme.semanticSelectionColor : Color.clear)
        }
    }

    var minecraftContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            if let selectedMinecraftVersion {
                MinecraftVersionInstallDetailPage(
                    version: selectedMinecraftVersion,
                    instances: instanceStore.instances,
                    selectedInstance: instanceStore.selectedInstance,
                    target: $minecraftInstallTarget,
                    instanceName: $minecraftInstanceName,
                    loader: $selectedMinecraftLoader,
                    loaderVersion: $selectedMinecraftLoaderVersion,
                    shaderLoader: $selectedShaderLoader,
                    shaderLoaderVersion: $selectedShaderLoaderVersion,
                    loaderOptions: minecraftLoaderOptions,
                    shaderReleases: minecraftShaderReleases,
                    versionOptionsStatus: minecraftVersionOptionsStatus,
                    confirmInstall: $confirmMinecraftInstall,
                    preflight: minecraftInstallPreflight,
                    preflightStatus: minecraftInstallPreflightStatus,
                    choicePreflights: minecraftInstallChoicePreflights,
                    lastInstallFailure: viewModel.lastTaskFailure,
                    back: {
                        self.selectedMinecraftVersion = nil
                    },
                    install: installSelectedMinecraftVersion,
                    openTasks: openTasks,
                    exportDiagnostics: exportMinecraftInstallDiagnostics,
                    openInstanceDirectory: openMinecraftInstallDirectory,
                    downloadJava: downloadMinecraftInstallJava
                )
            } else {
                MinecraftVersionBrowsePage(
                    versions: versionStore.versions,
                    latestReleaseID: versionStore.latestReleaseID,
                    latestSnapshotID: versionStore.latestSnapshotID,
                    status: versionStore.versionStatus,
                    searchText: $minecraftSearchText,
                    group: $minecraftBrowseGroup,
                    page: $minecraftPage,
                    refresh: refreshMinecraftVersions,
                    select: openMinecraftInstallDetail
                )
            }
        }
    }

    var resourcesContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            if selectedSource == .curseForge && !onlineContentStore.hasCurseForgeAPIKey() {
                CurseForgeAPIKeyInlineEditor(
                    apiKey: $curseForgeAPIKey,
                    openSettings: openDownloadSettings,
                    onSaved: refreshOnlineContent
                )
            }

            if let failure = onlineContentStore.searchFailures[selectedSource] {
                OnlineSearchErrorBanner(
                    source: selectedSource,
                    message: failure,
                    requestSnapshot: onlineContentStore.searchFailureSnapshots[selectedSource],
                    proxyAddress: $launcherSettings.proxyAddress,
                    retry: refreshOnlineContentApplyingNetworkSettings,
                    switchSource: switchSource,
                    openSettings: openDownloadSettings
                )
            }

            resourcesWorkspace
        }
    }

    var resourcesWorkspace: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.fontDensity.spacing) {
                searchResultsPanel(viewportHeight: resourceWorkspaceHeight)
                    .frame(minWidth: 520, maxWidth: .infinity, alignment: .top)
                if selectedProject != nil {
                    selectedProjectDetailContent(showBackButton: false, viewportHeight: resourceWorkspaceHeight)
                        .frame(width: resourceInspectorWidth, height: resourceWorkspaceHeight, alignment: .top)
                }
            }
            .frame(height: resourceWorkspaceHeight, alignment: .top)

            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                if selectedProject != nil, showingProjectDetail {
                    selectedProjectDetailContent(showBackButton: true)
                } else {
                    searchResultsPanel
                }
            }
        }
    }

    @ViewBuilder
    func selectedProjectDetailContent(showBackButton: Bool, viewportHeight: CGFloat? = nil) -> some View {
        if let selectedProject {
            let detail = VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    if showBackButton {
                        GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Back to results", chinese: "返回结果", italian: "Torna ai risultati", french: "Retour aux résultats", spanish: "Volver a resultados")) {
                            showingProjectDetail = false
                        }
                    }

                    OnlineProjectDetailPanel(
                        presentation: showBackButton ? .full : .inspector,
                        project: selectedProject,
                        releases: onlineContentStore.selectedReleases,
                        selectedReleaseID: $selectedReleaseID,
                        currentMinecraftVersion: selectedContentMinecraftVersionID,
                        targetResolution: targetResolution,
                        selectedTargetID: $selectedContentTargetID,
                        targetFailure: targetResolutionFailure,
                        projectFailure: onlineContentStore.projectFailure,
                        isLoading: onlineContentStore.isLoading,
                        retryLoad: { onlineContentStore.loadProject(selectedProject.id, sourceID: selectedProject.source, query: searchQuery) },
                        install: installSelectedRelease,
                        openTasks: openTasks
                    )
                }

            if let viewportHeight {
                ScrollView {
                    detail
                }
                .frame(height: viewportHeight)
                .scrollIndicators(.visible)
                .scrollClipDisabled(false)
            } else {
                detail
            }
        }
    }

    private var resourceWorkspaceHeight: CGFloat {
        let windowHeight = NSApp.keyWindow?.contentLayoutRect.height ?? NSScreen.main?.visibleFrame.height ?? 920
        return min(max(windowHeight - 360, 580), 860)
    }

    private var resourceInspectorWidth: CGFloat {
        560
    }

    var targetContextBar: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedString(theme.language, english: "Minecraft version filter", chinese: "Minecraft 版本过滤", italian: "Filtro versione Minecraft", french: "Filtre de version Minecraft", spanish: "Filtro de versión de Minecraft"))
                        .font(.caption.weight(.semibold))
                    Text(targetContextSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                    refreshOnlineContent()
                }
                .disabled(!canSearchSelectedSource || onlineContentStore.isLoading)
                Menu {
                    Button(localizedString(theme.language, english: "All Minecraft versions", chinese: "全部 Minecraft 版本", italian: "Tutte le versioni Minecraft", french: "Toutes les versions Minecraft", spanish: "Todas las versiones de Minecraft")) {
                        useMinecraftVersionFilter = false
                        selectedContentMinecraftVersionID = nil
                    }
                    Divider()
                    if releaseMinecraftVersions.isEmpty {
                        Button(AppText.refresh.localized(theme.language)) {
                            refreshMinecraftVersions()
                        }
                    } else {
                        ForEach(releaseMinecraftVersions) { version in
                            Button(versionMenuTitle(version)) {
                                useMinecraftVersionFilter = true
                                selectedContentMinecraftVersionID = version.id
                            }
                        }
                    }
                } label: {
                    Label(localizedString(theme.language, english: "Choose Version", chinese: "选择版本", italian: "Scegli versione", french: "Choisir la version", spanish: "Elegir versión"), systemImage: "arrow.left.arrow.right")
                }
                .menuStyle(.button)
            }
        }
    }

    var targetContextSummary: String {
        guard useMinecraftVersionFilter else {
            return localizedString(theme.language, english: "No Minecraft version filter selected. Search results are not tied to a local instance.", chinese: "未选择 Minecraft 版本过滤；搜索结果不会绑定本地实例。", italian: "Nessun filtro versione Minecraft selezionato.", french: "Aucun filtre de version Minecraft sélectionné.", spanish: "No se seleccionó filtro de versión de Minecraft.")
        }
        guard let selectedContentMinecraftVersionID else {
            return localizedString(theme.language, english: "Choose a Minecraft version to filter compatible content.", chinese: "请选择 Minecraft 版本，用于筛选兼容内容。", italian: "Scegli una versione Minecraft per filtrare i contenuti compatibili.", french: "Choisissez une version Minecraft pour filtrer le contenu compatible.", spanish: "Elige una versión de Minecraft para filtrar contenido compatible.")
        }
        return localizedString(theme.language, english: "Browsing content compatible with Minecraft \(selectedContentMinecraftVersionID). Install targets are chosen later.", chinese: "正在浏览兼容 Minecraft \(selectedContentMinecraftVersionID) 的内容；安装目标稍后再选。", italian: "Contenuti compatibili con Minecraft \(selectedContentMinecraftVersionID).", french: "Contenu compatible avec Minecraft \(selectedContentMinecraftVersionID).", spanish: "Contenido compatible con Minecraft \(selectedContentMinecraftVersionID).")
    }

    func versionMenuTitle(_ version: MinecraftVersionInfo) -> String {
        let kind = version.kind.title(language: theme.language)
        if version.id == versionStore.latestReleaseID {
            return localizedString(theme.language, english: "\(version.id) · Latest release", chinese: "\(version.id) · 最新正式版", italian: "\(version.id) · Ultima release", french: "\(version.id) · Dernière release", spanish: "\(version.id) · Última release")
        }
        return "\(version.id) · \(kind)"
    }

    var searchResultsPanel: some View {
        searchResultsPanel()
    }

    func searchResultsPanel(viewportHeight: CGFloat? = nil) -> some View {
        GlassPanel(showsShadow: false, surfaceLevel: .panel) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Results", chinese: "搜索结果", italian: "Risultati", french: "Résultats", spanish: "Resultados"),
                        systemImage: "list.bullet.rectangle"
                    )
                    Spacer()
                    if onlineContentStore.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    if let lastSearchUpdatedText {
                        Text(lastSearchUpdatedText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    CountText(value: projects.count)
                }

                if onlineContentStore.isLoading && projects.isEmpty {
                    OnlineProjectSkeletonList()
                } else if let failure = onlineContentStore.searchFailures[selectedSource], projects.isEmpty {
                    OnlineRequestFailedView(
                        source: selectedSource,
                        message: failure,
                        retry: refreshOnlineContent,
                        switchSource: switchSource
                    )
                } else if projects.isEmpty {
                    OnlineEmptyResultsView(
                        source: selectedSource,
                        canSearch: canSearchSelectedSource,
                        isVersionFiltered: useMinecraftVersionFilter && selectedContentMinecraftVersionID != nil,
                        retry: refreshOnlineContent,
                        relaxVersionFilter: relaxMinecraftVersionFilter,
                        switchSource: switchSource
                    )
                } else {
                    projectResultsList(viewportHeight: viewportHeight)
                    onlinePageControls
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: viewportHeight, alignment: .top)
    }

    @ViewBuilder
    private func projectResultsList(viewportHeight: CGFloat?) -> some View {
        let rows = LazyVStack(spacing: 6) {
            ForEach(projects) { project in
                OnlineProjectResultRow(
                    project: project,
                    isSelected: selectedProject?.id == project.id
                ) {
                    showingProjectDetail = true
                    selectedReleaseID = nil
                    targetResolution = nil
                    targetResolutionFailure = nil
                    onlineContentStore.selectProjectPreview(project)
                    onlineContentStore.loadProject(project.id, sourceID: project.source, query: searchQuery)
                }
            }
        }

        if let viewportHeight {
            ScrollView {
                rows
                    .padding(.trailing, 4)
            }
            .frame(height: max(viewportHeight - 92, 260), alignment: .top)
            .scrollIndicators(.visible)
            .scrollClipDisabled(false)
        } else {
            rows
        }
    }

    private var onlinePageControls: some View {
        HStack {
            Text(onlinePageStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if onlineContentStore.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Color.clear
                    .frame(width: 18, height: 18)
            }
            GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Previous", chinese: "上一页", italian: "Precedente", french: "Précédent", spanish: "Anterior")) {
                goToOnlinePage(max(onlinePage - 1, 0))
            }
            .disabled(onlinePage <= 0 || onlineContentStore.isLoading)
            GlassButton(systemImage: "chevron.right", title: localizedString(theme.language, english: "Next", chinese: "下一页", italian: "Successiva", french: "Suivant", spanish: "Siguiente")) {
                goToOnlinePage(onlinePage + 1)
            }
            .disabled(!hasNextOnlinePage || onlineContentStore.isLoading)
        }
    }

    var searchPanel: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                searchInputRow
                searchFilterRow

                categoryChips

                if !activeFilterSummary.isEmpty {
                    MetadataLine(items: activeFilterSummary, font: .caption.weight(.semibold))
                }
            }
        }
    }

    var searchPanelHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                searchPanelTitle
                Spacer(minLength: 12)
                searchSourceControls
            }

            VStack(alignment: .leading, spacing: 10) {
                searchPanelTitle
                searchSourceControls
            }
        }
    }

    private var searchPanelTitle: some View {
        PanelHeader(
            title: localizedString(theme.language, english: "Online Downloads", chinese: "在线下载", italian: "Download online", french: "Téléchargements en ligne", spanish: "Descargas online"),
            systemImage: "arrow.down.app"
        )
    }

    private var searchSourceControls: some View {
        HStack(spacing: 8) {
            PaninoGlassSegmentedRail {
                Picker("", selection: $selectedSource) {
                    Text(ContentSourceID.modrinth.displayName).tag(ContentSourceID.modrinth)
                    Text(localizedString(theme.language, english: "CurseForge (Advanced)", chinese: "CurseForge（高级）", italian: "CurseForge (avanzato)", french: "CurseForge (avancé)", spanish: "CurseForge (avanzado)"))
                        .tag(ContentSourceID.curseForge)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(minWidth: 210, idealWidth: 260, maxWidth: 300)
            }
            ToolbarIconButton(
                systemImage: "doc.on.doc",
                title: localizedString(theme.language, english: "Copy Search Debug", chinese: "复制搜索诊断", italian: "Copia debug ricerca", french: "Copier debug recherche", spanish: "Copiar depuración"),
                action: copySearchDebugSummary
            )
        }
    }

    var searchInputRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchTextField
                searchSubmitButton
            }

            VStack(alignment: .leading, spacing: 10) {
                searchTextField
                searchSubmitButton
            }
        }
    }

    private var searchTextField: some View {
        PaninoTextInput(
            localizedString(theme.language, english: "Search mods, packs, resources...", chinese: "搜索 Mod、整合包、资源包...", italian: "Cerca mod, pacchetti, risorse...", french: "Rechercher mods, packs, ressources...", spanish: "Buscar mods, packs, recursos..."),
            text: $searchText
        ) {
            refreshOnlineContent()
        }
    }

    private var searchSubmitButton: some View {
        GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Search", chinese: "搜索", italian: "Cerca", french: "Rechercher", spanish: "Buscar"), prominent: true) {
            refreshOnlineContent()
        }
        .disabled(!canSearchSelectedSource || onlineContentStore.isLoading)
    }

    var searchFilterRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchFilterControls
            }

            VStack(alignment: .leading, spacing: 10) {
                searchFilterControls
            }
        }
    }

    @ViewBuilder
    private var searchFilterControls: some View {
        Picker(localizedString(theme.language, english: "Sort", chinese: "排序", italian: "Ordina", french: "Tri", spanish: "Orden"), selection: $selectedSort) {
            ForEach(OnlineContentSort.allCases, id: \.self) { sort in
                Text(sort.title(language: theme.language)).tag(sort)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 170)

        Picker(AppText.loader.localized(theme.language), selection: $selectedLoader) {
            Text(localizedString(theme.language, english: "Any Loader", chinese: "任意加载器", italian: "Qualsiasi loader", french: "Tous les chargeurs", spanish: "Cualquier loader"))
                .tag(nil as LoaderFamily?)
            ForEach(LoaderFamily.allCases) { loader in
                Text(loader.displayTitle).tag(loader as LoaderFamily?)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 170)

        Toggle(localizedString(theme.language, english: "Match Minecraft version", chinese: "匹配 Minecraft 版本", italian: "Abbina versione Minecraft", french: "Adapter la version Minecraft", spanish: "Coincidir versión de Minecraft"), isOn: $useMinecraftVersionFilter)
            .toggleStyle(.checkbox)

        versionFilterMenu

        if useMinecraftVersionFilter, let selectedContentMinecraftVersionID {
            MetadataLine(items: ["Minecraft \(selectedContentMinecraftVersionID)"], font: .caption.weight(.semibold))
        }
    }

    var versionFilterMenu: some View {
        Menu {
            Button(localizedString(theme.language, english: "All Minecraft versions", chinese: "全部 Minecraft 版本", italian: "Tutte le versioni Minecraft", french: "Toutes les versions Minecraft", spanish: "Todas las versiones de Minecraft")) {
                useMinecraftVersionFilter = false
                selectedContentMinecraftVersionID = nil
            }
            Divider()
            if releaseMinecraftVersions.isEmpty {
                Button(AppText.refresh.localized(theme.language)) {
                    refreshMinecraftVersions()
                }
            } else {
                ForEach(releaseMinecraftVersions) { version in
                    Button(versionMenuTitle(version)) {
                        useMinecraftVersionFilter = true
                        selectedContentMinecraftVersionID = version.id
                    }
                }
            }
        } label: {
            Label(localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), systemImage: "slider.horizontal.3")
        }
        .menuStyle(.button)
        .disabled(onlineContentStore.isLoading)
    }

    var lastSearchUpdatedText: String? {
        guard let date = onlineContentStore.lastSearchUpdatedAt else { return nil }
        return localizedString(
            theme.language,
            english: "Updated \(date.formatted(date: .omitted, time: .shortened))",
            chinese: "更新于 \(date.formatted(date: .omitted, time: .shortened))",
            italian: "Aggiornato \(date.formatted(date: .omitted, time: .shortened))",
            french: "Mis à jour \(date.formatted(date: .omitted, time: .shortened))",
            spanish: "Actualizado \(date.formatted(date: .omitted, time: .shortened))"
        )
    }

    @ViewBuilder
    var categoryChips: some View {
        if !categoryOptions.isEmpty {
            let tokens = theme.resolvedTokens(
                reduceTransparency: reduceTransparency,
                increasedContrast: colorSchemeContrast == .increased,
                reduceMotion: reduceMotion || theme.reducesInterfaceMotion
            )
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedString(theme.language, english: "Intent", chinese: "内容意图", italian: "Intento", french: "Intention", spanish: "Intención"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    categoryFilterButton(
                        title: localizedString(theme.language, english: "All", chinese: "全部", italian: "Tutti", french: "Tout", spanish: "Todo"),
                        isSelected: selectedCategory == nil
                    ) {
                        selectCategory(nil)
                    }
                    ForEach(primaryCategoryOptions) { category in
                        categoryFilterButton(title: category.title(language: theme.language), isSelected: selectedCategory == category.id) {
                            selectCategory(category.id)
                        }
                    }
                    if !overflowCategoryOptions.isEmpty {
                        Menu {
                            ForEach(overflowCategoryOptions) { category in
                                Button(category.title(language: theme.language)) {
                                    selectCategory(category.id)
                                }
                            }
                        } label: {
                            Label(localizedString(theme.language, english: "More", chinese: "更多", italian: "Altro", french: "Plus", spanish: "Más"), systemImage: "ellipsis")
                        }
                        .menuStyle(.button)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 32)
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: tokens.controlCornerRadius + 4, style: .continuous)
                        .fill(Color.clear)
                        .paninoGlassSurface(
                            tokens: tokens,
                            level: .panel,
                            cornerRadius: tokens.controlCornerRadius + 4,
                            interactive: true
                        )
                        .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.24))
                        .paninoDepthOverlay(tokens: tokens, level: .panel, cornerRadius: tokens.controlCornerRadius + 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: tokens.controlCornerRadius + 4, style: .continuous)
                        .strokeBorder(tokens.strokeColor.opacity(tokens.strokeOpacity * 0.46), lineWidth: tokens.strokeWidth)
                }
            }
        }
    }

    func categoryFilterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion || theme.reducesInterfaceMotion
        )
        return Button(action: action) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(isSelected ? theme.semanticSelectionColor : Color.clear)
                    .frame(width: 3, height: 16)
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 132, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                            ? theme.semanticSelectionColor.opacity(0.18)
                            : Color(nsColor: .controlBackgroundColor).opacity(0.10)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isSelected ? tokens.depthHighlightOpacity * 1.30 : tokens.depthHighlightOpacity * 0.58),
                                        Color.clear,
                                        Color.black.opacity(isSelected ? tokens.depthShadeOpacity * 0.70 : tokens.depthShadeOpacity * 0.36)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isSelected
                            ? theme.semanticSelectionColor.opacity(0.70)
                            : Color(nsColor: .separatorColor).opacity(0.28),
                        lineWidth: 1
                    )
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    var searchQuery: OnlineSearchQuery {
        OnlineSearchQuery(
            text: searchText,
            projectTypes: [selectedType],
            categories: selectedCategory.map { Set([$0]) } ?? [],
            gameVersion: useMinecraftVersionFilter ? selectedContentMinecraftVersionID : nil,
            loaders: Set(effectiveSearchLoaders),
            sort: selectedSort,
            offset: onlinePage * 30,
            limit: 30
        )
    }

    var effectiveSearchLoaders: [LoaderFamily] {
        if let selectedLoader {
            return [selectedLoader]
        }
        return []
    }

    var activeFilterSummary: [String] {
        [
            selectedType.displayTitle,
            selectedCategoryOption?.title(language: theme.language),
            selectedLoader?.displayTitle,
            useMinecraftVersionFilter ? selectedContentMinecraftVersionID.map { "Minecraft \($0)" } : nil
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
    }

    var onlinePageStatus: String {
        guard let page = onlineContentStore.searchResults[selectedSource] else { return "" }
        let start = page.offset + 1
        let end = min(page.offset + page.projects.count, page.total)
        return localizedString(
            theme.language,
            english: "\(start)-\(end) of \(page.total) results",
            chinese: "第 \(start)-\(end) 个，共 \(page.total) 个结果",
            italian: "\(start)-\(end) di \(page.total) risultati",
            french: "\(start)-\(end) sur \(page.total) résultats",
            spanish: "\(start)-\(end) de \(page.total) resultados"
        )
    }

    var hasNextOnlinePage: Bool {
        guard let page = onlineContentStore.searchResults[selectedSource] else { return false }
        if let hasMore = page.hasMore {
            return hasMore
        }
        if page.nextPrefetchKey != nil {
            return true
        }
        return page.offset + page.projects.count < page.total
    }

    var sourceStatusText: String {
        if !canSearchSelectedSource {
            return localizedString(
                theme.language,
                english: "\(selectedSource.displayName) requires an API key before searching.",
                chinese: "\(selectedSource.displayName) 需要用户自备 API Key 后才能搜索。",
                italian: "\(selectedSource.displayName) richiede una chiave API prima della ricerca.",
                french: "\(selectedSource.displayName) nécessite une clé API avant la recherche.",
                spanish: "\(selectedSource.displayName) requiere una API key antes de buscar."
            )
        }
        if let failure = onlineContentStore.searchFailures[selectedSource] {
            return "\(selectedSource.displayName): \(localizedOnlineError(failure, language: theme.language))"
        }
        if let page = onlineContentStore.searchResults[selectedSource] {
            return localizedString(
                theme.language,
                english: "Loaded \(page.projects.count) \(selectedSource.displayName) projects",
                chinese: "已加载 \(page.projects.count) 个 \(selectedSource.displayName) 项目",
                italian: "Caricati \(page.projects.count) progetti \(selectedSource.displayName)",
                french: "\(page.projects.count) projets \(selectedSource.displayName) chargés",
                spanish: "\(page.projects.count) proyectos de \(selectedSource.displayName) cargados"
            )
        }
        return onlineContentStore.statusMessage
    }
}

private struct DiscoverImmersiveBackground: View {
    let section: DiscoverSection

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        sectionTint.opacity(0.64),
                        theme.semanticSelectionColor.opacity(0.28),
                        Color(nsColor: .windowBackgroundColor).opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.80
                )

                Image(systemName: section.symbolName)
                    .font(.system(size: min(proxy.size.width, 520) * 0.34, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.13))
                    .offset(x: proxy.size.width * 0.26, y: -proxy.size.height * 0.08)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var sectionTint: Color {
        switch section {
        case .minecraft:
            return Color(red: 0.24, green: 0.62, blue: 0.34)
        case .mods:
            return Color(red: 0.36, green: 0.42, blue: 0.92)
        case .modpacks:
            return Color(red: 0.87, green: 0.36, blue: 0.27)
        case .resources:
            return Color(red: 0.27, green: 0.62, blue: 0.84)
        case .shaders:
            return Color(red: 0.92, green: 0.55, blue: 0.22)
        }
    }
}

private struct DiscoverImmersivePrimary: View {
    let title: String
    let subtitle: String
    let metadata: [String]
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetadataLine(items: metadata, font: .caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            Text(title)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

            Text(subtitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: 760, alignment: .leading)

            if !status.isEmpty {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.22), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DiscoverMinecraftSceneShelf: View {
    let versionCount: Int
    let status: String
    @Binding var searchText: String
    @Binding var group: MinecraftBrowseGroup
    let refresh: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    minecraftSearchField
                    groupPicker
                    refreshButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    minecraftSearchField
                    HStack(spacing: 10) {
                        groupPicker
                        refreshButton
                    }
                }
            }

            HStack(spacing: 8) {
                ImmersiveTextPill(
                    title: localizedString(theme.language, english: "Catalog", chinese: "目录", italian: "Catalogo", french: "Catalogue", spanish: "Catalogo"),
                    value: localizedString(theme.language, english: "\(versionCount) versions", chinese: "\(versionCount) 个版本", italian: "\(versionCount) versioni", french: "\(versionCount) versions", spanish: "\(versionCount) versiones")
                )

                if !status.isEmpty {
                    ImmersiveTextPill(
                        title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "Etat", spanish: "Estado"),
                        value: status
                    )
                }
            }
        }
        .padding(14)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.panel, tint: theme.semanticSelectionColor)
    }

    private var minecraftSearchField: some View {
        PaninoTextInput(
            localizedString(theme.language, english: "Search version, e.g. 1.20.1", chinese: "搜索版本，例如 1.20.1", italian: "Cerca versione, es. 1.20.1", french: "Rechercher version, ex. 1.20.1", spanish: "Buscar version, ej. 1.20.1"),
            text: $searchText
        )
        .frame(minWidth: 260, idealWidth: 420, maxWidth: 560)
    }

    private var groupPicker: some View {
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

    private var refreshButton: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refresh)
    }
}

private extension DiscoverSection {
    var symbolName: String {
        switch self {
        case .minecraft:
            return "cube.box.fill"
        case .mods:
            return "shippingbox.fill"
        case .modpacks:
            return "square.stack.3d.up.fill"
        case .resources:
            return "photo.stack.fill"
        case .shaders:
            return "sun.max.fill"
        }
    }
}
