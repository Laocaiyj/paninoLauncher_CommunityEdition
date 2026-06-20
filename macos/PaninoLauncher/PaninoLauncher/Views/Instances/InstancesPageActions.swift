import AppKit
import Foundation
import UniformTypeIdentifiers

extension InstancesPage {
    func openRequestedInstanceContent(_ kind: ManagedAssetKind?) {
        guard let kind, let section = InstancePropertySection.section(for: kind) else { return }
        guard let selected = instanceStore.selectedInstance else { return }
        let available = InstancePropertySection.availableSections(for: selected)
        guard available.contains(section) else { return }
        versionStore.selectedAssetKind = kind
        propertySection = section
        showingProperties = true
        versionStore.refreshAssets(for: selected)
    }

    func launchSelectedInstance(_ instance: GameInstance) {
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

    func archiveSelectedInstance() {
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

    func moveOutSelectedInstance() {
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

    func deleteSelectedInstanceFiles() {
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

    func restoreArchivedInstance() {
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
}
