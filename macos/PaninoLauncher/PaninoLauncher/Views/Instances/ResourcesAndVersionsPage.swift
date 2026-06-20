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
            ResourcesManagementPanel(
                selectedInstance: selectedInstance,
                isAssetKindAvailable: isCurrentAssetKindAvailable(capabilities: capabilities),
                assetSearchText: $assetSearchText,
                selectedSort: $versionStore.selectedAssetSort,
                filteredManagedAssets: filteredManagedAssets,
                groupedAssets: groupedAssets,
                selectedAssetIDs: selectedAssetIDs,
                emptyTitle: AppText.noItems.localized(theme.language, versionStore.selectedAssetKind.title(language: theme.language)),
                fileStatus: versionStore.fileStatus,
                updatePlanStatus: updatePlanStatus,
                installActionTitle: installActionTitle,
                unavailableTitle: unavailableTitle,
                unavailableDescription: unavailableDescription,
                refresh: {
                    configureVersionCoreBackend()
                    versionStore.refreshAssets(for: instanceStore.selectedInstance)
                },
                openFolder: {
                    versionStore.openFolder(for: instanceStore.selectedInstance)
                },
                openDiscover: {
                    openDiscover?()
                },
                selectAll: {
                    selectedAssetIDs = Set(filteredManagedAssets.map(\.id))
                },
                sortChanged: {
                    versionStore.refreshAssets(for: instanceStore.selectedInstance)
                },
                toggleSelection: toggleSelection,
                toggleAsset: { asset in
                    versionStore.toggle(asset, instance: instanceStore.selectedInstance)
                },
                linkAsset: { asset in
                    pendingAssetLink = asset
                    assetLinkSource = asset.source ?? ""
                    assetLinkURL = asset.projectURL?.absoluteString ?? ""
                },
                deleteAsset: { asset in
                    pendingAssetDelete = asset
                }
            )

            if !selectedAssetIDs.isEmpty {
                SelectedAssetActionBar(
                    selectedCount: selectedAssetIDs.count,
                    update: prepareContentUpdatePlan,
                    enable: {
                        selectedAssets.filter { !$0.isEnabled }.forEach { versionStore.toggle($0, instance: instanceStore.selectedInstance) }
                        selectedAssetIDs.removeAll()
                    },
                    disable: {
                        selectedAssets.filter(\.isEnabled).forEach { versionStore.toggle($0, instance: instanceStore.selectedInstance) }
                        selectedAssetIDs.removeAll()
                    },
                    delete: {
                        confirmBatchDelete = true
                    },
                    deselect: {
                        selectedAssetIDs.removeAll()
                    }
                )
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
            coreBackend: .live(viewModel: viewModel)
        )
    }
}
