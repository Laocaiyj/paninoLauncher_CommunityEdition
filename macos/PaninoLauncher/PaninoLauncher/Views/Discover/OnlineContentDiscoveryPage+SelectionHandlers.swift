import Foundation

extension OnlineContentDiscoveryPage {
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
}
