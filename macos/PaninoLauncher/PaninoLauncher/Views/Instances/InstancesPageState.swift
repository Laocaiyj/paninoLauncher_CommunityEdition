import Foundation

extension InstancesPage {
    var sceneInstance: GameInstance? {
        if let selected = instanceStore.selectedInstance {
            return selected
        }
        return filteredInstances.first ?? instanceStore.instances.first
    }

    var filteredInstances: [GameInstance] {
        sortInstances(searchMatchedInstances.filter { matchesFilter($0, filter: filter) })
    }

    var collectionCounts: [InstanceFilter: Int] {
        Dictionary(uniqueKeysWithValues: InstanceFilter.allCases.map { item in
            (item, searchMatchedInstances.filter { matchesFilter($0, filter: item) }.count)
        })
    }

    func deleteConfirmationMessage(_ instance: GameInstance) -> String {
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

    func refreshSelectedInstanceVersionState() {
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

    func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: .live(viewModel: viewModel)
        )
    }

    func isolatedDirectoryPath(for instance: GameInstance) -> String? {
        let path = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        guard let root = try? LauncherPaths.gameConfigurationsDirectory().standardizedFileURL.path else {
            return nil
        }
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        guard standardized == root || standardized.hasPrefix(root + "/") else { return nil }
        return standardized
    }

    func instanceArchiveTargetPath(instance: GameInstance, suffix: String) -> String {
        let root = ((try? LauncherPaths.backupsDirectory(category: "Instances"))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher/Backups/Instances", isDirectory: true))
        return root
            .appendingPathComponent("\(safeFileComponent(instance.name))-\(timestamp())-\(suffix).zip")
            .path
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
}
