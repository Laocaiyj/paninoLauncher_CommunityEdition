import SwiftUI

extension LaunchDashboard {
    func performPrimaryAction() {
        if viewModel.coreState.isReady == false {
            Task { await viewModel.startCoreIfNeeded() }
            return
        }
        if let summary = selectedLaunchSummary,
           summary.status == "needsInstall" || summary.status == "missing" || summary.status == "notInstalled" {
            installSelectedVersion(launchAfterInstall: true)
            return
        }
        if selectedInstance.status == .notInstalled {
            installSelectedVersion(launchAfterInstall: true)
            return
        }
        if hasBlockingLaunchFailure(selectedInstance) {
            openLogs()
            return
        }
        launchSelectedInstance()
    }

    func selectAndLaunch(_ instanceID: UUID) {
        instanceStore.selectedInstanceID = instanceID
        performPrimaryAction()
    }

    func openDetail(_ instanceID: UUID) {
        instanceStore.selectedInstanceID = instanceID
        detailInstanceID = instanceID
    }

    func refreshLaunchLibrarySummary() async {
        do {
            let summary = try await viewModel.launchLibrary(instances: instanceStore.instances)
            launchLibrarySummary = summary
        } catch {
            viewModel.appendLog("Launch library summary failed: \(error.localizedDescription)")
        }
    }

    func launchSelectedInstance() {
        guard !selectedInstance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel.appendLog("Launch blocked: selected instance has no isolated game directory")
            return
        }
        applyInstanceSettings()
        viewModel.launch(accountID: defaultAccountID, gameDir: selectedInstance.gameDirectory, instance: selectedInstance)
    }

    func installSelectedVersion(launchAfterInstall: Bool = false) {
        guard !selectedInstance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel.appendLog("Install blocked: selected instance has no isolated game directory")
            return
        }
        pendingLaunchAfterRepairInstanceID = launchAfterInstall ? selectedInstance.id : nil
        applyInstanceSettings()
        viewModel.install(gameDir: selectedInstance.gameDirectory)
    }

    func continuePendingLaunchAfterRepairIfReady(_ task: TaskSnapshot?) {
        guard let pendingID = pendingLaunchAfterRepairInstanceID,
              let task,
              task.kind == "install",
              task.state.isTerminal
        else { return }
        pendingLaunchAfterRepairInstanceID = nil
        guard task.state == .succeeded else { return }
        instanceStore.selectedInstanceID = pendingID
        launchSelectedInstance()
    }

    func refreshSelectedVersionState() {
        configureVersionCoreBackend()
        versionStore.selectedVersionID = selectedInstance.minecraftVersion
        versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
        versionStore.loadDetails(
            for: versionStore.versions.first { $0.id == selectedInstance.minecraftVersion },
            instances: instanceStore.instances,
            settings: launcherSettings
        )
    }

    func refreshSelectedJavaRuntime() {
        if viewModel.managedJavaRuntimes.isEmpty {
            viewModel.loadManagedJavaRuntimes()
        }
        let customPath = selectedInstance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? SettingsStore.javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
            : selectedInstance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.resolveJavaRuntime(
            version: selectedInstance.contentMinecraftVersion,
            gameDir: selectedInstance.gameDirectory,
            instanceId: selectedInstance.id.uuidString,
            customPath: customPath.isEmpty ? nil : customPath
        )
    }

    func retryLaunchTask() {
        if viewModel.currentTask?.kind == "install" {
            installSelectedVersion(launchAfterInstall: false)
            return
        }
        launchSelectedInstance()
    }

    func backupSaves(for instance: GameInstance) {
        let source = URL(fileURLWithPath: instance.gameDirectory, isDirectory: true)
            .appendingPathComponent("saves", isDirectory: true)
            .path
        runArchiveOperation(
            instance: instance,
            kind: "backup",
            sourcePath: source,
            backupCategory: "saves",
            title: localizedString(theme.language, english: "Backup Saves", chinese: "备份存档", italian: "Backup salvataggi", french: "Sauvegarder", spanish: "Respaldar partidas"),
            filenameSuffix: "saves"
        )
    }

    func exportInstance(for instance: GameInstance) {
        runArchiveOperation(
            instance: instance,
            kind: "export",
            sourcePath: instance.gameDirectory,
            backupCategory: "instances",
            title: localizedString(theme.language, english: "Export Instance", chinese: "导出实例", italian: "Esporta istanza", french: "Exporter instance", spanish: "Exportar instancia"),
            filenameSuffix: "instance"
        )
    }

    private func runArchiveOperation(
        instance: GameInstance,
        kind: String,
        sourcePath: String,
        backupCategory: String,
        title: String,
        filenameSuffix: String
    ) {
        guard !sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            taskCenterStore.upsertLocal(
                kind: kind,
                name: title,
                state: .failed,
                progress: 0,
                errorCode: "missing_source",
                message: "Archive source path is missing."
            )
            return
        }

        let taskID = UUID().uuidString
        taskCenterStore.upsertLocal(
            id: taskID,
            kind: kind,
            name: title,
            version: instance.minecraftVersion,
            state: .running,
            progress: 0.1,
            currentFile: sourcePath,
            message: "Core preflight queued."
        )

        Task {
            do {
                let targetPath = try archiveTargetPath(
                    instance: instance,
                    category: backupCategory,
                    suffix: filenameSuffix
                )
                let preflight = try await viewModel.exportBackupPreflight(
                    for: instance,
                    kind: kind,
                    targetPath: targetPath
                )
                guard preflight.allowed else {
                    await MainActor.run {
                        _ = taskCenterStore.upsertLocal(
                            id: taskID,
                            kind: kind,
                            name: title,
                            version: instance.minecraftVersion,
                            state: .failed,
                            progress: 1,
                            currentFile: sourcePath,
                            errorCode: "preflight_blocked",
                            message: preflight.blockingReasons.joined(separator: ", ")
                        )
                    }
                    return
                }

                let response = try await viewModel.archiveLocalDirectory(
                    sourcePath: sourcePath,
                    targetPath: targetPath
                )
                await MainActor.run {
                    let warnings = preflight.warnings.isEmpty ? "" : " Warnings: \(preflight.warnings.joined(separator: ", "))"
                    taskCenterStore.upsertLocal(
                        id: taskID,
                        kind: kind,
                        name: title,
                        version: instance.minecraftVersion,
                        state: .succeeded,
                        progress: 1,
                        currentFile: response.path ?? targetPath,
                        message: "\(response.message): \(response.path ?? targetPath).\(warnings)"
                    )
                    viewModel.appendLog("\(title) completed: \(response.path ?? targetPath)")
                }
            } catch {
                await MainActor.run {
                    taskCenterStore.upsertLocal(
                        id: taskID,
                        kind: kind,
                        name: title,
                        version: instance.minecraftVersion,
                        state: .failed,
                        progress: 1,
                        currentFile: sourcePath,
                        errorCode: "archive_failed",
                        message: error.localizedDescription
                    )
                    viewModel.appendLog("\(title) failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func archiveTargetPath(instance: GameInstance, category: String, suffix: String) throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "\(safeArchiveName(instance.name))-\(suffix)-\(formatter.string(from: Date())).zip"
        return try LauncherPaths.backupsDirectory(category: category)
            .appendingPathComponent(filename)
            .path
    }

    private func safeArchiveName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        var result = ""
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "panino-instance" : trimmed
    }

    func applyInstanceSettings() {
        viewModel.version = selectedInstance.minecraftVersion
        let usesGlobalJava = selectedInstance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        viewModel.memoryMb = selectedInstance.memoryPolicy == .custom
            ? (selectedInstance.customMemoryMb ?? selectedInstance.memoryMb)
            : SettingsStore.memoryMb
        viewModel.javaPath = usesGlobalJava ? SettingsStore.javaPath : selectedInstance.javaPath
        if let loader = selectedInstance.loader {
            versionStore.selectedLoader = loader
        }
    }

    func updateSelectedInstance(_ mutate: (inout GameInstance) -> Void) {
        guard let selectedID = instanceStore.selectedInstance?.id,
              let index = instanceStore.instances.firstIndex(where: { $0.id == selectedID }) else { return }
        mutate(&instanceStore.instances[index])
    }

    func updateInstance(_ instanceID: UUID, mutate: (inout GameInstance) -> Void) {
        guard let index = instanceStore.instances.firstIndex(where: { $0.id == instanceID }) else { return }
        mutate(&instanceStore.instances[index])
    }

    func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: .live(viewModel: viewModel)
        )
    }
}
