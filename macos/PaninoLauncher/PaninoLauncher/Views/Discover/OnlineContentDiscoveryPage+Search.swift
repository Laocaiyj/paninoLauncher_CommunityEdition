import AppKit
import SwiftUI

extension OnlineContentDiscoveryPage {
    func handleDiscoveryTask() {
        configureCoreBackend()
        configureVersionCoreBackend()
        syncManagedKind()
        versionStore.refreshAssets(for: instanceStore.selectedInstance)
        if !versionStore.hasRemoteVersions {
            refreshMinecraftVersions()
        }
        if selectedSection != .minecraft, projects.isEmpty {
            search(clearExisting: false)
        }
    }

    func handleSelectedSectionChanged() {
        selectedMinecraftVersion = nil
        clearOnlineSelectionContext(clearCategory: true)
        if let projectType = selectedSection.projectType {
            selectedType = projectType
            syncManagedKind()
            refreshOnlineContent()
        } else {
            refreshMinecraftVersions()
        }
    }

    func handleSelectedSourceChanged() {
        selectedReleaseID = nil
        clearOnlineSelectionContext(clearCategory: true)
        onlinePage = 0
        if canSearchSelectedSource {
            refreshOnlineContent()
        } else {
            onlineContentStore.requireConfiguration(for: selectedSource)
        }
    }

    func handleSelectedTypeChanged() {
        clearOnlineSelectionContext(clearCategory: true)
        syncManagedKind()
        onlinePage = 0
        refreshOnlineContent()
    }

    func handleSelectedSortChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        onlinePage = 0
        refreshOnlineContent()
    }

    func handleSelectedLoaderChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        onlinePage = 0
        refreshOnlineContent()
    }

    func handleUseMinecraftVersionFilterChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        onlinePage = 0
        guard !useMinecraftVersionFilter || selectedContentMinecraftVersionID != nil else { return }
        refreshOnlineContent()
    }

    func handleSelectedContentMinecraftVersionChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        selectedReleaseID = recommendedReleaseID()
        onlinePage = 0
        guard useMinecraftVersionFilter else { return }
        refreshOnlineContent()
        resolveTargetsForSelection()
    }

    func handleSelectedReleasesChanged() {
        selectedReleaseID = recommendedReleaseID()
        resolveTargetsForSelection()
    }

    func handleSelectedReleaseIDChanged() {
        resolveTargetsForSelection()
    }

    func handleMinecraftBrowseGroupChanged() {
        minecraftPage = 0
    }

    func handleMinecraftSearchTextChanged() {
        minecraftPage = 0
    }

    func search(clearExisting: Bool = false, completion: ((Bool) -> Void)? = nil) {
        searchDebounceTask?.cancel()
        guard canSearchSelectedSource else {
            onlineContentStore.requireConfiguration(for: selectedSource)
            completion?(false)
            return
        }
        configureCoreBackend()
        syncManagedKind()
        onlineContentStore.search(searchQuery, sources: [selectedSource], clearExisting: clearExisting, completion: completion)
    }

    func refreshOnlineContent() {
        onlinePage = 0
        targetResolution = nil
        targetResolutionFailure = nil
        search(clearExisting: false)
    }

    func refreshOnlineContentApplyingNetworkSettings() {
        let proxyAddress = launcherSettings.proxyAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !proxyAddress.isEmpty else {
            refreshOnlineContent()
            return
        }

        onlinePage = 0
        targetResolution = nil
        targetResolutionFailure = nil
        SettingsStore.set(proxyAddress, forKey: "Settings.ProxyAddress")
        Task { @MainActor in
            await viewModel.shutdownCore()
            await viewModel.startCoreIfNeeded()
            search(clearExisting: false)
        }
    }

    func debounceSearch() {
        guard selectedSection != .minecraft else { return }
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onlinePage = 0
                clearOnlineSelectionContext(clearCategory: false)
                search(clearExisting: false)
            }
        }
    }

    func goToOnlinePage(_ nextPage: Int) {
        let targetPage = max(nextPage, 0)
        guard targetPage != onlinePage else { return }
        let previousPage = onlinePage
        onlinePage = targetPage
        targetResolution = nil
        targetResolutionFailure = nil
        selectedContentTargetID = nil
        search(clearExisting: false) { success in
            if !success {
                onlinePage = previousPage
            }
        }
    }

    func selectCategory(_ categoryID: String?) {
        guard selectedCategory != categoryID else { return }
        selectedCategory = categoryID
        onlinePage = 0
        clearOnlineSelectionContext(clearCategory: false)
        if categoryID != nil && selectedSort == .downloads {
            selectedSort = .relevance
        } else {
            refreshOnlineContent()
        }
    }

    func relaxMinecraftVersionFilter() {
        useMinecraftVersionFilter = false
        selectedContentMinecraftVersionID = nil
    }

    func clearOnlineSelectionContext(clearCategory: Bool) {
        if clearCategory {
            selectedCategory = nil
        }
        selectedReleaseID = nil
        showingProjectDetail = false
        targetResolution = nil
        targetResolutionFailure = nil
        selectedContentTargetID = nil
        onlineContentStore.clearSelection()
    }

    func copySearchDebugSummary() {
        let summary = searchQuery.diagnosticSummary(source: selectedSource)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    func configureCoreBackend() {
        onlineContentStore.configure(
            coreBackend: OnlineContentCoreBackend(
                search: { query, source, apiKey in
                    try await viewModel.searchContent(query, source: source, curseForgeAPIKey: apiKey)
                },
                project: { projectID, source, query, apiKey in
                    try await viewModel.contentProject(id: projectID, source: source, query: query, curseForgeAPIKey: apiKey)
                },
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                loaderMetadata: { minecraftVersion in
                    try await viewModel.loaderMetadata(for: minecraftVersion)
                }
            )
        )
    }

    func configureVersionCoreBackend() {
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

    func refreshMinecraftVersions() {
        configureVersionCoreBackend()
        versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
    }
}
