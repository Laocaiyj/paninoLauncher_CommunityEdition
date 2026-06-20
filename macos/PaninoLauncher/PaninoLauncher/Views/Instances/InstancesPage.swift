import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InstancesPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openResources: () -> Void
    let openDiscover: () -> Void
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var appActions: AppActionCenter
    @State private var searchText = ""
    @State private var sort: InstanceSort = .favoritesFirst
    @State private var filter: InstanceFilter = .all
    @State private var confirmDelete = false
    @State private var showingProperties = false
    @State private var propertySection: InstancePropertySection = .overview
    @State private var instanceOperationStatus = ""
    @State private var isMutatingInstance = false

    var body: some View {
        Group {
            if showingProperties, let binding = instanceStore.selectedInstanceBinding {
                InstancePropertiesPage(
                    viewModel: viewModel,
                    instance: binding,
                    section: $propertySection,
                    openDiscover: openDiscover,
                    onBack: { showingProperties = false },
                    onDuplicate: instanceStore.duplicateSelected,
                    onDelete: { confirmDelete = true },
                    onArchive: archiveSelectedInstance,
                    onMoveOut: moveOutSelectedInstance,
                    onRestoreArchive: restoreArchivedInstance
                )
            } else {
                instanceLibrary
            }
        }
        .task {
            configureVersionCoreBackend()
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: instanceStore.selectedInstanceID) {
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: instanceStore.selectedInstance?.minecraftVersion ?? "") {
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: appActions.instanceContentSequence) {
            openRequestedInstanceContent(appActions.requestedInstanceContentKind)
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete this game configuration?", chinese: "删除此游戏配置？", italian: "Eliminare questa configurazione?", french: "Supprimer cette configuration ?", spanish: "¿Eliminar esta configuración?"),
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(localizedString(theme.language, english: "Delete Game Configuration", chinese: "删除游戏配置", italian: "Elimina configurazione", french: "Supprimer configuration", spanish: "Eliminar configuración"), role: .destructive) {
                deleteSelectedInstanceFiles()
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            if let selected = instanceStore.selectedInstance {
                Text(deleteConfirmationMessage(selected))
            }
        }
    }

    private func openRequestedInstanceContent(_ kind: ManagedAssetKind?) {
        guard let kind, let section = InstancePropertySection.section(for: kind) else { return }
        guard let selected = instanceStore.selectedInstance else { return }
        let available = InstancePropertySection.availableSections(for: selected)
        guard available.contains(section) else { return }
        versionStore.selectedAssetKind = kind
        propertySection = section
        showingProperties = true
        versionStore.refreshAssets(for: selected)
    }

    private var instanceLibrary: some View {
        ImmersivePageScaffold(
            minHeight: 720,
            backgroundContent: {
                InstanceImmersiveBackground(instance: sceneInstance)
            },
            primaryContent: {
                InstanceImmersivePrimary(
                    instance: sceneInstance,
                    totalCount: instanceStore.instances.count,
                    filteredCount: filteredInstances.count,
                    statusText: instanceOperationStatus.isEmpty ? instanceStore.storageStatus : instanceOperationStatus,
                    openDiscover: openDiscover
                )
            },
            floatingControls: {
                InstanceImmersiveControls(
                    instance: sceneInstance,
                    canSubmitTask: viewModel.canSubmitTask,
                    isMutatingInstance: isMutatingInstance,
                    launch: { instance in launchSelectedInstance(instance) },
                    openProperties: { instance in
                        instanceStore.selectedInstanceID = instance.id
                        propertySection = .overview
                        showingProperties = true
                    },
                    openFolder: { instance in FinderIntegration.openInstanceDirectory(instance) },
                    restoreArchive: restoreArchivedInstance,
                    openDiscover: openDiscover
                )
            },
            contextShelf: {
                InstanceImmersiveShelf(
                    searchText: $searchText,
                    sort: $sort,
                    filter: $filter,
                    counts: collectionCounts,
                    instances: filteredInstances,
                    selectedInstanceID: instanceStore.selectedInstanceID,
                    canLaunch: viewModel.canSubmitTask,
                    selectInstance: { instance in
                        instanceStore.selectedInstanceID = instance.id
                    },
                    launch: { instance in launchSelectedInstance(instance) },
                    openProperties: { instance, section in
                        instanceStore.selectedInstanceID = instance.id
                        propertySection = section
                        showingProperties = true
                    },
                    openFolder: { instance in
                        FinderIntegration.openInstanceDirectory(instance)
                    }
                )
            }
        )
    }

    private var sceneInstance: GameInstance? {
        if let selected = instanceStore.selectedInstance {
            return selected
        }
        return filteredInstances.first ?? instanceStore.instances.first
    }

    private var filteredInstances: [GameInstance] {
        sortInstances(searchMatchedInstances.filter { matchesFilter($0, filter: filter) })
    }

    private var collectionCounts: [InstanceFilter: Int] {
        Dictionary(uniqueKeysWithValues: InstanceFilter.allCases.map { item in
            (item, searchMatchedInstances.filter { matchesFilter($0, filter: item) }.count)
        })
    }

    private var searchMatchedInstances: [GameInstance] {
        instanceStore.instances.filter { instance in
            searchText.isEmpty
                || instance.name.localizedCaseInsensitiveContains(searchText)
                || instance.minecraftVersion.localizedCaseInsensitiveContains(searchText)
                || instance.group.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func sortInstances(_ instances: [GameInstance]) -> [GameInstance] {
        switch sort {
        case .favoritesFirst:
            return instances.sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .name:
            return instances.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private func matchesFilter(_ instance: GameInstance, filter: InstanceFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .favorites:
            return instance.isFavorite
        case .needsAttention:
            return instance.status == .failed || instance.status == .notInstalled
        }
    }

    private func launchSelectedInstance(_ instance: GameInstance) {
        viewModel.version = instance.minecraftVersion
        let usesGlobalRuntime = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        viewModel.memoryMb = usesGlobalRuntime ? SettingsStore.memoryMb : instance.memoryMb
        viewModel.javaPath = usesGlobalRuntime ? SettingsStore.javaPath : instance.javaPath
        if let loader = instance.loader {
            versionStore.selectedLoader = loader
        }
        viewModel.launch(
            accountID: accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID,
            gameDir: instance.gameDirectory,
            instance: instance
        )
    }

    private func deleteConfirmationMessage(_ instance: GameInstance) -> String {
        let directory = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return localizedString(
            theme.language,
            english: "\(instance.name)\nFolder: \(directory)\nThis moves the whole isolated instance folder to Trash and removes the local record.",
            chinese: "\(instance.name)\n目录：\(directory)\n这会把整个隔离实例目录移到废纸篓，并移除本地记录。",
            italian: "\(instance.name)\nCartella: \(directory)\nSposta l'intera istanza nel Cestino.",
            french: "\(instance.name)\nDossier : \(directory)\nDéplace toute l'instance dans la Corbeille.",
            spanish: "\(instance.name)\nCarpeta: \(directory)\nMueve toda la instancia a la Papelera."
        )
    }

    private func archiveSelectedInstance() {
        guard let instance = instanceStore.selectedInstance else { return }
        guard let sourcePath = isolatedDirectoryPath(for: instance) else {
            instanceOperationStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is archiving the instance...", chinese: "Core 正在归档实例...", italian: "Core archivia l'istanza...", french: "Core archive l'instance...", spanish: "Core está archivando la instancia...")
        let targetPath = instanceArchiveTargetPath(instance: instance, suffix: "instance")
        Task {
            await runInstanceArchive(instance: instance, sourcePath: sourcePath, targetPath: targetPath, removeAfterArchive: false)
        }
    }

    private func moveOutSelectedInstance() {
        guard let instance = instanceStore.selectedInstance else { return }
        guard let sourcePath = isolatedDirectoryPath(for: instance) else {
            instanceOperationStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is archiving and moving out the instance...", chinese: "Core 正在归档并移出实例...", italian: "Core archivia e sposta fuori l'istanza...", french: "Core archive et déplace l'instance...", spanish: "Core está archivando y moviendo la instancia...")
        let targetPath = instanceArchiveTargetPath(instance: instance, suffix: "moved-out")
        Task {
            await runInstanceArchive(instance: instance, sourcePath: sourcePath, targetPath: targetPath, removeAfterArchive: true)
        }
    }

    private func deleteSelectedInstanceFiles() {
        guard let instance = instanceStore.selectedInstance else { return }
        guard let sourcePath = isolatedDirectoryPath(for: instance) else {
            instanceStore.remove(instance)
            showingProperties = false
            return
        }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is moving the instance to Trash...", chinese: "Core 正在把实例移到废纸篓...", italian: "Core sposta l'istanza nel Cestino...", french: "Core déplace l'instance dans la Corbeille...", spanish: "Core está moviendo la instancia a la Papelera...")
        Task {
            do {
                let response = try await viewModel.deleteLocalResource(path: sourcePath)
                await MainActor.run {
                    instanceStore.remove(instance)
                    showingProperties = false
                    isMutatingInstance = false
                    instanceOperationStatus = response.path ?? response.message
                    refreshSelectedInstanceVersionState()
                }
            } catch {
                await MainActor.run {
                    isMutatingInstance = false
                    instanceOperationStatus = error.localizedDescription
                }
            }
        }
    }

    private func restoreArchivedInstance() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = localizedString(theme.language, english: "Choose an archived Panino instance zip.", chinese: "选择一个 Panino 实例归档 zip。", italian: "Scegli zip istanza Panino.", french: "Choisissez une archive d'instance Panino.", spanish: "Elige un zip de instancia Panino.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is restoring the archived instance...", chinese: "Core 正在恢复归档实例...", italian: "Core ripristina l'istanza...", french: "Core restaure l'instance...", spanish: "Core está restaurando la instancia...")
        let targetRoot = ((try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true))
            .path
        Task {
            do {
                let response = try await viewModel.importLocalArchive(archivePath: url.path, targetDir: targetRoot, deleteArchive: true)
                await MainActor.run {
                    isMutatingInstance = false
                    instanceOperationStatus = response.message
                    refreshSelectedInstanceVersionState()
                }
            } catch {
                await MainActor.run {
                    isMutatingInstance = false
                    instanceOperationStatus = error.localizedDescription
                }
            }
        }
    }

    private func runInstanceArchive(instance: GameInstance, sourcePath: String, targetPath: String, removeAfterArchive: Bool) async {
        do {
            let archiveResponse = try await viewModel.archiveLocalDirectory(sourcePath: sourcePath, targetPath: targetPath)
            if removeAfterArchive {
                _ = try await viewModel.deleteLocalResource(path: sourcePath)
            }
            await MainActor.run {
                if removeAfterArchive {
                    instanceStore.remove(instance)
                    showingProperties = false
                }
                isMutatingInstance = false
                instanceOperationStatus = archiveResponse.path ?? archiveResponse.message
                refreshSelectedInstanceVersionState()
            }
        } catch {
            await MainActor.run {
                isMutatingInstance = false
                instanceOperationStatus = error.localizedDescription
            }
        }
    }

    private func isolatedDirectoryPath(for instance: GameInstance) -> String? {
        let path = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        guard let root = try? LauncherPaths.gameConfigurationsDirectory().standardizedFileURL.path else {
            return nil
        }
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        guard standardized == root || standardized.hasPrefix(root + "/") else { return nil }
        return standardized
    }

    private func instanceArchiveTargetPath(instance: GameInstance, suffix: String) -> String {
        let root = ((try? LauncherPaths.backupsDirectory(category: "Instances"))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher/Backups/Instances", isDirectory: true))
        return root
            .appendingPathComponent("\(safeFileComponent(instance.name))-\(timestamp())-\(suffix).zip")
            .path
    }

    private func safeFileComponent(_ value: String) -> String {
        SafeFileComponent.sanitize(
            value,
            allowedExtraCharacters: "-_",
            fallback: "instance"
        )
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func refreshSelectedInstanceVersionState() {
        configureVersionCoreBackend()
        guard let selected = instanceStore.selectedInstance else {
            versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
            return
        }
        versionStore.selectedVersionID = selected.minecraftVersion
        versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
        versionStore.loadDetails(
            for: versionStore.versions.first { $0.id == selected.minecraftVersion },
            instances: instanceStore.instances,
            settings: launcherSettings
        )
    }

    private func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: .live(viewModel: viewModel)
        )
    }
}
