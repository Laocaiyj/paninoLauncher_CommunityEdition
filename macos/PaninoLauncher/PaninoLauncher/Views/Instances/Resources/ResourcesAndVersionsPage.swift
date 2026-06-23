import SwiftUI

struct ResourcesManagementPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    var openDiscover: (() -> Void)? = nil
    @EnvironmentObject var versionStore: VersionContentStore
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var theme: ThemeSettings
    @State var assetSearchText = ""
    @State var selectedAssetIDs: Set<String> = []
    @State var pendingAssetDelete: ManagedAsset?
    @State var confirmBatchDelete = false
    @State var pendingAssetLink: ManagedAsset?
    @State var assetLinkSource = ""
    @State var assetLinkURL = ""
    @State var pendingUpdateReview: PendingContentUpdateReview?
    @State var updatePlanStatus = ""

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
}
