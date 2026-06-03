import SwiftUI

private struct PendingContentUpdateReview: Identifiable {
    let id = UUID()
    let response: CoreContentUpdatePlanResponse
}

struct ResourcesManagementPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    var openDiscover: (() -> Void)? = nil
    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings
    @State private var assetSearchText = ""
    @State private var selectedAssetIDs: Set<String> = []
    @State private var pendingAssetDelete: ManagedAsset?
    @State private var confirmBatchDelete = false
    @State private var pendingAssetLink: ManagedAsset?
    @State private var assetLinkSource = ""
    @State private var assetLinkURL = ""
    @State private var pendingUpdateReview: PendingContentUpdateReview?
    @State private var updatePlanStatus = ""

    var body: some View {
        let selectedInstance = instanceStore.selectedInstance
        let capabilities = selectedInstance.map(GameConfigurationCapabilities.capabilities)
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    HStack {
                        PanelHeader(title: localizedString(theme.language, english: "Current Configuration Resources", chinese: "当前游戏配置资源", italian: "Risorse configurazione attuale", french: "Ressources de la configuration", spanish: "Recursos de configuración"), systemImage: "folder.badge.gearshape")
                        Spacer()
                        if let instance = instanceStore.selectedInstance {
                            MetadataLine(items: ["Minecraft \(instance.minecraftVersion)", instance.loaderTitle(language: theme.language)])
                        }
                        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                            configureVersionCoreBackend()
                            versionStore.refreshAssets(for: instanceStore.selectedInstance)
                        }
                        GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                            versionStore.openFolder(for: instanceStore.selectedInstance)
                        }
                    }

                    if isCurrentAssetKindAvailable(capabilities: capabilities) {
                    HStack(spacing: 8) {
                        PaninoTextInput(
                            localizedString(theme.language, english: "Search installed content", chinese: "搜索已安装内容", italian: "Cerca contenuti installati", french: "Rechercher contenu installé", spanish: "Buscar contenido instalado"),
                            text: $assetSearchText
                        )

                        GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                            versionStore.openFolder(for: instanceStore.selectedInstance)
                        }

                        GlassButton(systemImage: "arrow.down.app", title: installActionTitle) {
                            openDiscover?()
                        }

                        GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Select All", chinese: "全选", italian: "Seleziona tutto", french: "Tout sélectionner", spanish: "Seleccionar todo")) {
                            selectedAssetIDs = Set(filteredManagedAssets.map(\.id))
                        }
                        .disabled(filteredManagedAssets.isEmpty)
                    }

                    SettingsRow(title: localizedString(theme.language, english: "Sort", chinese: "排序", italian: "Ordina", french: "Tri", spanish: "Orden"), systemImage: "arrow.up.arrow.down") {
                        Picker(localizedString(theme.language, english: "Sort"), selection: $versionStore.selectedAssetSort) {
                            ForEach(ManagedAssetSort.allCases) { sort in
                                Text(sort.title(language: theme.language)).tag(sort)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: versionStore.selectedAssetSort) {
                            versionStore.refreshAssets(for: instanceStore.selectedInstance)
                        }
                    }

                    Text(
                        localizedString(
                            theme.language,
                            english: "Installed content is scoped to the selected game configuration. Drop .jar or .zip files anywhere in this window to import through Core.",
                            chinese: "已安装内容以当前游戏配置为上下文。可将 .jar 或 .zip 文件拖入窗口并通过 Core 导入。",
                            italian: "Il contenuto installato è legato all'istanza selezionata. Trascina .jar o .zip nella finestra per importare via Core.",
                            french: "Le contenu installé est lié à la configuration sélectionnée. Déposez .jar ou .zip pour importer via Core.",
                            spanish: "El contenido instalado pertenece a la instancia seleccionada. Suelta .jar o .zip para importar mediante Core."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if filteredManagedAssets.isEmpty {
                        ContentUnavailableView(
                            AppText.noItems.localized(theme.language, versionStore.selectedAssetKind.title(language: theme.language)),
                            systemImage: "tray",
                            description: Text(versionStore.fileStatus)
                        )
                        .frame(minHeight: 220)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(groupedAssets, id: \.title) { group in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(group.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                    ForEach(group.assets) { asset in
                                        HStack(alignment: .center, spacing: 8) {
                                            Button {
                                                toggleSelection(asset.id)
                                            } label: {
                                                Image(systemName: selectedAssetIDs.contains(asset.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedAssetIDs.contains(asset.id) ? theme.semanticSelectionColor : .secondary)
                                                    .frame(width: 22)
                                            }
                                            .buttonStyle(.plain)

                                            ManagedAssetRow(asset: asset) {
                                                versionStore.toggle(asset, instance: instanceStore.selectedInstance)
                                            } onLink: {
                                                pendingAssetLink = asset
                                                assetLinkSource = asset.source ?? ""
                                                assetLinkURL = asset.projectURL?.absoluteString ?? ""
                                            } onDelete: {
                                                pendingAssetDelete = asset
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    } else {
                        ContentUnavailableView(
                            unavailableTitle,
                            systemImage: "exclamationmark.circle",
                            description: Text(unavailableDescription)
                        )
                        .frame(minHeight: 220)
                    }

                    Text(versionStore.fileStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if !updatePlanStatus.isEmpty {
                        Text(updatePlanStatus)
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            }

            if !selectedAssetIDs.isEmpty {
                selectedAssetActionBar
            }
        }
        .task {
            configureVersionCoreBackend()
            syncSelectedLoader()
            versionStore.refreshAssets(for: instanceStore.selectedInstance)
        }
        .onChange(of: versionStore.selectedAssetKind) {
            selectedAssetIDs.removeAll()
            syncSelectedLoader()
            versionStore.refreshAssets(for: instanceStore.selectedInstance)
        }
        .onChange(of: assetSearchText) {
            selectedAssetIDs = selectedAssetIDs.filter { id in
                filteredManagedAssets.contains { $0.id == id }
            }
        }
        .confirmationDialog(
            AppText.deleteSelectedFile.localized(theme.language),
            isPresented: Binding(
                get: { pendingAssetDelete != nil },
                set: { if !$0 { pendingAssetDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(AppText.deleteFile.localized(theme.language), role: .destructive) {
                if let pendingAssetDelete {
                    versionStore.delete(pendingAssetDelete, instance: instanceStore.selectedInstance)
                }
                pendingAssetDelete = nil
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {
                pendingAssetDelete = nil
            }
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete selected files?", chinese: "删除选中文件？", italian: "Eliminare file selezionati?", french: "Supprimer les fichiers sélectionnés ?", spanish: "¿Eliminar archivos seleccionados?"),
            isPresented: $confirmBatchDelete,
            titleVisibility: .visible
        ) {
            Button(AppText.delete.localized(theme.language), role: .destructive) {
                selectedAssets.forEach { versionStore.delete($0, instance: instanceStore.selectedInstance) }
                selectedAssetIDs.removeAll()
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        }
        .sheet(item: $pendingAssetLink) { asset in
            AssetLinkEditor(
                asset: asset,
                source: $assetLinkSource,
                projectURLText: $assetLinkURL
            ) {
                versionStore.link(
                    asset,
                    source: assetLinkSource,
                    projectURL: URL(string: assetLinkURL),
                    instance: instanceStore.selectedInstance
                )
                pendingAssetLink = nil
            }
        }
        .sheet(item: $pendingUpdateReview) { review in
            InstallPlanReviewSheet(
                plan: review.response.typedPlan,
                title: localizedString(theme.language, english: "Review update plan", chinese: "确认更新计划", italian: "Controlla piano aggiornamento", french: "Vérifier la mise à jour", spanish: "Revisar actualización"),
                subtitle: localizedString(theme.language, english: "\(selectedAssetIDs.count) selected files", chinese: "已选 \(selectedAssetIDs.count) 个文件", italian: "\(selectedAssetIDs.count) file selezionati", french: "\(selectedAssetIDs.count) fichiers sélectionnés", spanish: "\(selectedAssetIDs.count) archivos seleccionados"),
                confirmTitle: localizedString(theme.language, english: "Update", chinese: "更新", italian: "Aggiorna", french: "Mettre à jour", spanish: "Actualizar"),
                repairTitle: localizedString(theme.language, english: "Open Discover", chinese: "打开获取", italian: "Apri scoperta", french: "Ouvrir Découvrir", spanish: "Abrir Descubrir"),
                onCancel: { pendingUpdateReview = nil },
                onRepair: {
                    pendingUpdateReview = nil
                    openDiscover?()
                },
                onConfirm: {
                    pendingUpdateReview = nil
                    updatePlanStatus = localizedString(theme.language, english: "Update execution is waiting for resolved remote releases.", chinese: "更新执行需要先解析远端版本。", italian: "L'esecuzione richiede release remote risolte.", french: "L'exécution nécessite des versions distantes résolues.", spanish: "La ejecución necesita versiones remotas resueltas.")
                }
            )
            .environmentObject(theme)
        }
    }

    private var filteredManagedAssets: [ManagedAsset] {
        let query = assetSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return versionStore.managedAssets }
        return versionStore.managedAssets.filter { asset in
            [
                asset.name,
                asset.metadata.displayName,
                asset.metadata.version,
                asset.metadata.summary,
                asset.source,
                asset.projectURL?.absoluteString
            ]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var groupedAssets: [(title: String, assets: [ManagedAsset])] {
        [
            (localizedString(theme.language, english: "Needs Attention", chinese: "需要处理", italian: "Richiede attenzione", french: "À vérifier", spanish: "Requiere atención"), filteredManagedAssets.filter { $0.conflictMessage != nil }),
            (localizedString(theme.language, english: "Enabled", chinese: "已启用", italian: "Abilitati", french: "Activés", spanish: "Activados"), filteredManagedAssets.filter { $0.conflictMessage == nil && $0.isEnabled }),
            (localizedString(theme.language, english: "Disabled", chinese: "已禁用", italian: "Disabilitati", french: "Désactivés", spanish: "Desactivados"), filteredManagedAssets.filter { $0.conflictMessage == nil && !$0.isEnabled })
        ]
        .filter { !$0.assets.isEmpty }
    }

    private var selectedAssets: [ManagedAsset] {
        versionStore.managedAssets.filter { selectedAssetIDs.contains($0.id) }
    }

    private var installActionTitle: String {
        switch versionStore.selectedAssetKind {
        case .mods:
            return localizedString(theme.language, english: "Install Mods", chinese: "安装 Mod", italian: "Installa Mod", french: "Installer Mods", spanish: "Instalar Mods")
        case .resourcePacks:
            return localizedString(theme.language, english: "Install Resources", chinese: "安装资源包", italian: "Installa risorse", french: "Installer ressources", spanish: "Instalar recursos")
        case .shaderPacks:
            return localizedString(theme.language, english: "Install Shaders", chinese: "安装光影包", italian: "Installa shader", french: "Installer shaders", spanish: "Instalar shaders")
        }
    }

    private var unavailableTitle: String {
        switch versionStore.selectedAssetKind {
        case .mods:
            return localizedString(theme.language, english: "Mods Need a Loader", chinese: "Mod 需要加载器", italian: "Le mod richiedono un loader", french: "Les mods nécessitent un loader", spanish: "Los mods necesitan un loader")
        case .shaderPacks:
            return localizedString(theme.language, english: "Shaders Need Shader Support", chinese: "光影需要兼容组件", italian: "Gli shader richiedono supporto", french: "Les shaders nécessitent un support", spanish: "Los shaders necesitan soporte")
        case .resourcePacks:
            return localizedString(theme.language, english: "Resource Packs Unavailable", chinese: "资源包不可用", italian: "Pacchetti risorse non disponibili", french: "Packs indisponibles", spanish: "Recursos no disponibles")
        }
    }

    private var unavailableDescription: String {
        switch versionStore.selectedAssetKind {
        case .mods:
            return localizedString(theme.language, english: "This Vanilla configuration has no Fabric, Forge, Quilt, or NeoForge loader. Install a Loader through the configuration install flow before managing Mods.", chinese: "这个原版配置没有 Fabric、Forge、Quilt 或 NeoForge。请先通过配置安装流程安装 Loader，再管理 Mod。", italian: "Questa configurazione Vanilla non ha loader.", french: "Cette configuration Vanilla n'a pas de loader.", spanish: "Esta configuración Vanilla no tiene loader.")
        case .shaderPacks:
            return localizedString(theme.language, english: "Install Iris, Oculus, or OptiFine through the Loader-aware flow before managing shader packs.", chinese: "请先通过带 Loader 预检的流程安装 Iris、Oculus 或 OptiFine，再管理光影包。", italian: "Installa Iris, Oculus o OptiFine prima.", french: "Installez Iris, Oculus ou OptiFine d'abord.", spanish: "Instala Iris, Oculus u OptiFine primero.")
        case .resourcePacks:
            return localizedString(theme.language, english: "Resource packs are normally available for every configuration.", chinese: "资源包通常可用于所有游戏配置。", italian: "I pacchetti risorse sono normalmente disponibili.", french: "Les packs sont normalement disponibles.", spanish: "Los recursos suelen estar disponibles.")
        }
    }

    private var selectedAssetActionBar: some View {
        GlassPanel {
            HStack(spacing: 10) {
                PlainStatusText(
                    title: localizedString(theme.language, english: "\(selectedAssetIDs.count) selected", chinese: "已选 \(selectedAssetIDs.count) 个", italian: "\(selectedAssetIDs.count) selezionati", french: "\(selectedAssetIDs.count) sélectionnés", spanish: "\(selectedAssetIDs.count) seleccionados"),
                    style: .download
                )
                Spacer()
                GlassButton(systemImage: "arrow.up.circle", title: localizedString(theme.language, english: "Update", chinese: "更新", italian: "Aggiorna", french: "Mettre à jour", spanish: "Actualizar")) {
                    prepareContentUpdatePlan()
                }
                GlassButton(systemImage: "play", title: AppText.enable.localized(theme.language)) {
                    selectedAssets.filter { !$0.isEnabled }.forEach { versionStore.toggle($0, instance: instanceStore.selectedInstance) }
                    selectedAssetIDs.removeAll()
                }
                GlassButton(systemImage: "pause", title: AppText.disable.localized(theme.language)) {
                    selectedAssets.filter(\.isEnabled).forEach { versionStore.toggle($0, instance: instanceStore.selectedInstance) }
                    selectedAssetIDs.removeAll()
                }
                GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language)) {
                    confirmBatchDelete = true
                }
                GlassButton(systemImage: "xmark", title: localizedString(theme.language, english: "Deselect", chinese: "取消选择", italian: "Deseleziona", french: "Désélectionner", spanish: "Deseleccionar")) {
                    selectedAssetIDs.removeAll()
                }
            }
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    private func isCurrentAssetKindAvailable(capabilities: GameConfigurationCapabilities?) -> Bool {
        guard let capabilities else { return false }
        switch versionStore.selectedAssetKind {
        case .mods:
            return capabilities.canManageMods
        case .resourcePacks:
            return capabilities.canManageResourcePacks
        case .shaderPacks:
            return capabilities.canManageShaderPacks
        }
    }

    private func syncSelectedLoader() {
        if let loader = instanceStore.selectedInstance?.loader {
            versionStore.selectedLoader = loader
        }
    }

    private func prepareContentUpdatePlan() {
        guard let instance = instanceStore.selectedInstance else { return }
        let assets = selectedAssets
        guard !assets.isEmpty else { return }
        updatePlanStatus = localizedString(theme.language, english: "Checking update plan...", chinese: "正在检查更新计划...", italian: "Controllo aggiornamenti...", french: "Vérification du plan...", spanish: "Revisando actualización...")
        let resources = assets.map { asset in
            CoreContentUpdatePlanResource(
                projectId: nil,
                projectTitle: asset.metadata.displayName ?? asset.name,
                currentReleaseId: asset.metadata.version ?? "local",
                currentFileName: asset.name,
                currentSha1: nil,
                currentTargetPath: asset.url.path,
                remoteReleaseId: "unresolved",
                remoteFileName: asset.name,
                remoteUrl: nil,
                remoteSha1: nil,
                remoteSize: nil,
                selected: true,
                dependencies: []
            )
        }
        let request = CoreContentUpdatePlanRequest(
            mode: "updateSelected",
            gameDir: instance.gameDirectory,
            source: "local",
            resources: resources
        )
        Task {
            do {
                let response = try await viewModel.contentUpdatePlan(request)
                await MainActor.run {
                    updatePlanStatus = response.blockedReasons.isEmpty ? "" : response.blockedReasons.joined(separator: ", ")
                    pendingUpdateReview = PendingContentUpdateReview(response: response)
                }
            } catch {
                await MainActor.run {
                    updatePlanStatus = error.localizedDescription
                }
            }
        }
    }

    private func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: VersionContentCoreBackend(
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftInstallStatus: { versionIds, gameDirs in
                    try await viewModel.minecraftInstallStatus(versionIds: versionIds, gameDirs: gameDirs)
                },
                installedMinecraftInstances: { versionIds, gameDirs in
                    try await viewModel.installedMinecraftInstances(versionIds: versionIds, gameDirs: gameDirs)
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                localResources: { gameDir, kind, loader in
                    try await viewModel.localResources(gameDir: gameDir, kind: kind, loader: loader)
                },
                toggleLocalResource: { path in
                    try await viewModel.toggleLocalResource(path: path)
                },
                deleteLocalResource: { path in
                    try await viewModel.deleteLocalResource(path: path)
                },
                importLocalResource: { sourcePath, gameDir, kind in
                    try await viewModel.importLocalResource(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
                },
                cleanMinecraftVersion: { version, gameDir in
                    try await viewModel.cleanMinecraftVersion(version: version, gameDir: gameDir)
                },
                mutateMinecraftVersionStorage: { version, gameDir, action in
                    try await viewModel.mutateMinecraftVersionStorage(version: version, gameDir: gameDir, action: action)
                }
            )
        )
    }
}

struct VersionsAndModsPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings
    @State private var versionSearchText = ""
    @State private var showReleaseVersions = false
    @State private var showSnapshots = false
    @State private var showHistorical = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    HStack {
                        PanelHeader(title: AppText.versionSelector.localized(theme.language), systemImage: "clock.arrow.circlepath")
                        Spacer()
                        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                            configureVersionCoreBackend()
                            versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
                        }
                    }

                    VersionBrowserHeader(
                        searchText: $versionSearchText,
                        usageFilter: $versionStore.versionUsageFilter
                    )

                    VersionBrowserSection(
                        title: localizedString(theme.language, english: "Recommended", chinese: "推荐", italian: "Consigliate", french: "Recommandées", spanish: "Recomendadas"),
                        versions: recommendedVersions,
                        selectedVersionID: versionStore.selectedVersion?.id,
                        select: selectVersion
                    )

                    FullWidthDisclosureGroup(isExpanded: $showReleaseVersions) {
                        VersionBrowserSection(
                            title: localizedString(theme.language, english: "Release", chinese: "正式版", italian: "Release", french: "Release", spanish: "Release"),
                            versions: filteredVersions(kind: .release),
                            selectedVersionID: versionStore.selectedVersion?.id,
                            select: selectVersion
                        )
                        .padding(.top, 8)
                    } label: {
                        Text("Release / Installed")
                            .font(.headline)
                    }

                    FullWidthDisclosureGroup(isExpanded: $showSnapshots) {
                        VersionBrowserSection(
                            title: localizedString(theme.language, english: "Snapshots", chinese: "快照版", italian: "Snapshot", french: "Snapshots", spanish: "Snapshots"),
                            versions: filteredVersions(kind: .snapshot),
                            selectedVersionID: versionStore.selectedVersion?.id,
                            select: selectVersion
                        )
                        .padding(.top, 8)
                    } label: {
                        Text("Snapshot")
                            .font(.headline)
                    }

                    FullWidthDisclosureGroup(isExpanded: $showHistorical) {
                        VersionBrowserSection(
                            title: localizedString(theme.language, english: "Historical", chinese: "历史版本", italian: "Storiche", french: "Historiques", spanish: "Históricas"),
                            versions: filteredVersions(kind: .oldBeta) + filteredVersions(kind: .oldAlpha),
                            selectedVersionID: versionStore.selectedVersion?.id,
                            select: selectVersion
                        )
                        .padding(.top, 8)
                    } label: {
                        Text("Old Beta / Old Alpha")
                            .font(.headline)
                    }

                    if let selectedVersion = versionStore.selectedVersion {
                        VersionDetailPanel(
                            version: selectedVersion,
                            status: versionStore.versionStatus,
                            install: {
                                viewModel.version = selectedVersion.id
                                viewModel.install(gameDir: instanceStore.selectedInstance?.gameDirectory)
                            },
                            repair: {
                                viewModel.version = selectedVersion.id
                                viewModel.install(gameDir: instanceStore.selectedInstance?.gameDirectory)
                            },
                            cleanUnused: {
                                versionStore.cleanUnusedVersion(selectedVersion, instances: instanceStore.instances, settings: launcherSettings)
                            }
                        )
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: AppText.loaderPlan.localized(theme.language), systemImage: "puzzlepiece.extension")

                    if compatibleLoaderKinds.isEmpty {
                        MetadataLine(items: [localizedString(theme.language, english: "Vanilla only", chinese: "仅原版", italian: "Solo Vanilla", french: "Vanilla uniquement", spanish: "Solo Vanilla")])
                    } else {
                        Picker(AppText.loader.localized(theme.language), selection: $versionStore.selectedLoader) {
                            ForEach(compatibleLoaderKinds) { loader in
                                Text(loader.title).tag(loader)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(loaderCompatibilityMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .task {
            configureVersionCoreBackend()
            versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
        }
    }

    private var recommendedVersions: [MinecraftVersionInfo] {
        uniqueVersions(
            currentInstanceVersions
                + latestReleaseVersions
                + versionStore.versions.filter(\.isInstalled)
                + versionStore.versions.filter(\.isUsedByInstance)
                + Array(versionStore.versions.filter { $0.kind == .release }.prefix(8))
        )
        .filter(matchesSearchAndUsage)
    }

    private var currentInstanceVersions: [MinecraftVersionInfo] {
        guard let currentVersion = instanceStore.selectedInstance?.minecraftVersion else { return [] }
        return versionStore.versions.filter { $0.id == currentVersion }
    }

    private var latestReleaseVersions: [MinecraftVersionInfo] {
        guard let latestReleaseID = versionStore.latestReleaseID else { return [] }
        return versionStore.versions.filter { $0.id == latestReleaseID }
    }

    private var compatibleLoaderKinds: [LoaderKind] {
        guard let selectedVersion = versionStore.selectedVersion else { return LoaderKind.allCases }
        return selectedVersion.kind == .oldAlpha || selectedVersion.kind == .oldBeta ? [] : LoaderKind.allCases
    }

    private var loaderCompatibilityMessage: String {
        guard let selectedVersion = versionStore.selectedVersion else {
            return AppText.loaderPlanDescription.localized(theme.language)
        }
        if selectedVersion.kind == .oldAlpha || selectedVersion.kind == .oldBeta {
            return localizedString(theme.language, english: "Historical versions default to Vanilla because modern loader metadata is not reliable.", chinese: "历史版本默认使用原版，因为现代 Loader 元数据不可可靠判断。", italian: "Le versioni storiche usano Vanilla perché i metadata loader non sono affidabili.", french: "Les versions historiques utilisent Vanilla car les métadonnées des loaders ne sont pas fiables.", spanish: "Las versiones históricas usan Vanilla porque los metadatos de loaders no son fiables.")
        }
        return AppText.loaderPlanDescription.localized(theme.language)
    }

    private func filteredVersions(kind: MinecraftVersionKind) -> [MinecraftVersionInfo] {
        versionStore.versions
            .filter { $0.kind == kind }
            .filter(matchesSearchAndUsage)
            .prefix(120)
            .map { $0 }
    }

    private func matchesSearchAndUsage(_ version: MinecraftVersionInfo) -> Bool {
        let query = versionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty || version.id.localizedCaseInsensitiveContains(query) else { return false }
        switch versionStore.versionUsageFilter {
        case .all:
            return true
        case .installed:
            return version.isInstalled
        case .usedByInstance:
            return version.isUsedByInstance
        }
    }

    private func selectVersion(_ version: MinecraftVersionInfo) {
        versionStore.selectedVersionID = version.id
        versionStore.loadDetails(
            for: version,
            instances: instanceStore.instances,
            settings: launcherSettings
        )
    }

    private func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: VersionContentCoreBackend(
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftInstallStatus: { versionIds, gameDirs in
                    try await viewModel.minecraftInstallStatus(versionIds: versionIds, gameDirs: gameDirs)
                },
                installedMinecraftInstances: { versionIds, gameDirs in
                    try await viewModel.installedMinecraftInstances(versionIds: versionIds, gameDirs: gameDirs)
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                localResources: { gameDir, kind, loader in
                    try await viewModel.localResources(gameDir: gameDir, kind: kind, loader: loader)
                },
                toggleLocalResource: { path in
                    try await viewModel.toggleLocalResource(path: path)
                },
                deleteLocalResource: { path in
                    try await viewModel.deleteLocalResource(path: path)
                },
                importLocalResource: { sourcePath, gameDir, kind in
                    try await viewModel.importLocalResource(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
                },
                cleanMinecraftVersion: { version, gameDir in
                    try await viewModel.cleanMinecraftVersion(version: version, gameDir: gameDir)
                },
                mutateMinecraftVersionStorage: { version, gameDir, action in
                    try await viewModel.mutateMinecraftVersionStorage(version: version, gameDir: gameDir, action: action)
                }
            )
        )
    }
}
