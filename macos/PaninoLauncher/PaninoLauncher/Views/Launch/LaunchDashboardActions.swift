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
