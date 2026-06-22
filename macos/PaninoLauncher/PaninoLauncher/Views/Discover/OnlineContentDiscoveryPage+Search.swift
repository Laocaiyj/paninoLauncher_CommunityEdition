import AppKit

extension OnlineContentDiscoveryPage {
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

    func copySearchDebugSummary() {
        let summary = searchQuery.diagnosticSummary(source: selectedSource)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
}
