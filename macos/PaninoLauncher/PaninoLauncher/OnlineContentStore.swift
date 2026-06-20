import Foundation

@MainActor
final class OnlineContentStore: ObservableObject {
    @Published private(set) var searchResults: [ContentSourceID: OnlineSearchPage] = [:]
    @Published private(set) var selectedProject: OnlineProject?
    @Published private(set) var selectedReleases: [OnlineRelease] = []
    @Published private(set) var minecraftVersions: [MinecraftRemoteVersion] = []
    @Published private(set) var selectedMinecraftPackage: MinecraftVersionPackage?
    @Published private(set) var loaderMetadata: [ContentSourceID: [LoaderMetadata]] = [:]
    @Published private(set) var searchFailures: [ContentSourceID: String] = [:]
    @Published private(set) var searchFailureSnapshots: [ContentSourceID: String] = [:]
    @Published private(set) var projectFailure: String?
    @Published private(set) var statusMessage = "Online content not loaded"
    @Published private(set) var isLoading = false
    @Published private(set) var lastSearchUpdatedAt: Date?
    @Published private(set) var curseForgeAPIKeyConfigured: Bool

    private let credentials = OnlineContentCredentialStore()
    private var backend: OnlineContentCoreBackend?
    private var searchTask: Task<Void, Never>?
    private var projectTask: Task<Void, Never>?
    private var versionTask: Task<Void, Never>?
    private var searchGeneration = 0
    private var projectGeneration = 0

    init() {
        curseForgeAPIKeyConfigured = credentials.curseForgeAPIKeyConfigured
    }

    func configure(coreBackend: OnlineContentCoreBackend) {
        backend = coreBackend
    }

    func hasCurseForgeAPIKey() -> Bool {
        curseForgeAPIKeyConfigured
    }

    func saveCurseForgeAPIKey(_ value: String) {
        do {
            curseForgeAPIKeyConfigured = try credentials.saveCurseForgeAPIKey(value)
            statusMessage = curseForgeAPIKeyConfigured
                ? "CurseForge API key saved in Keychain"
                : "CurseForge API key removed"
        } catch {
            statusMessage = "CurseForge API key update failed: \(error.localizedDescription)"
        }
    }

    func requireConfiguration(for source: ContentSourceID) {
        searchTask?.cancel()
        isLoading = false
        searchResults.removeValue(forKey: source)
        searchFailures.removeValue(forKey: source)
        searchFailureSnapshots.removeValue(forKey: source)
        if selectedProject?.source == source {
            selectedProject = nil
            selectedReleases = []
            projectFailure = nil
        }
        statusMessage = "\(source.displayName) requires API credentials before browsing."
    }

    func selectProjectPreview(_ project: OnlineProject) {
        projectTask?.cancel()
        selectedProject = project
        selectedReleases = []
        projectFailure = nil
        statusMessage = "Loading \(project.title)"
    }

    func clearSelection(for source: ContentSourceID? = nil) {
        projectTask?.cancel()
        guard source == nil || selectedProject?.source == source else { return }
        selectedProject = nil
        selectedReleases = []
        projectFailure = nil
    }

    func search(
        _ query: OnlineSearchQuery,
        sources requestedSources: [ContentSourceID] = [.modrinth],
        clearExisting: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let backend else {
            statusMessage = "Core backend is not ready for online content."
            completion?(false)
            return
        }

        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        isLoading = true
        statusMessage = "Searching online content via Core"
        for source in requestedSources {
            searchFailures.removeValue(forKey: source)
            searchFailureSnapshots.removeValue(forKey: source)
        }
        if clearExisting {
            clearSelection()
        }
        projectFailure = nil

        searchTask = Task {
            var batch = OnlineContentSearchBatchResult()

            for source in requestedSources {
                guard !Task.isCancelled else { return }
                do {
                    let page = try await backend.search(query, source, apiKey(for: source))
                    batch.addPage(page, for: source)
                } catch {
                    batch.addFailure(error, source: source, query: query)
                }
            }

            guard !Task.isCancelled, generation == searchGeneration else { return }
            for source in requestedSources {
                if let page = batch.pages[source] {
                    searchResults[source] = page
                }
                if let failure = batch.failuresBySource[source] {
                    searchFailures[source] = failure
                    searchFailureSnapshots[source] = batch.failureSnapshotsBySource[source]
                } else {
                    searchFailures.removeValue(forKey: source)
                    searchFailureSnapshots.removeValue(forKey: source)
                }
            }
            isLoading = false
            if !batch.pages.isEmpty {
                lastSearchUpdatedAt = Date()
            }
            statusMessage = batch.statusMessage
            completion?(batch.succeeded)
        }
    }

    func loadProject(_ projectID: String, sourceID: ContentSourceID, query: OnlineSearchQuery = OnlineSearchQuery()) {
        guard let backend else {
            statusMessage = "Core backend is not ready for project details."
            return
        }

        projectTask?.cancel()
        projectGeneration += 1
        let generation = projectGeneration
        isLoading = true
        statusMessage = "Loading project details via Core"
        projectFailure = nil

        projectTask = Task {
            do {
                let response = try await backend.project(projectID, sourceID, query, apiKey(for: sourceID))
                guard !Task.isCancelled, generation == projectGeneration else { return }
                selectedProject = response.project
                selectedReleases = response.releases
                statusMessage = "Loaded \(response.project.title)"
            } catch {
                guard !Task.isCancelled, generation == projectGeneration else { return }
                let message = OnlineContentErrorFormatter.displayMessage(for: error)
                projectFailure = message
                statusMessage = "Project load failed: \(message)"
            }
            guard !Task.isCancelled, generation == projectGeneration else { return }
            isLoading = false
        }
    }

    func refreshMinecraftVersions() {
        guard let backend else {
            statusMessage = "Core backend is not ready for Minecraft versions."
            return
        }

        versionTask?.cancel()
        statusMessage = "Refreshing Minecraft versions via Core"
        versionTask = Task {
            do {
                minecraftVersions = try await backend.minecraftVersions()
                statusMessage = "Loaded \(minecraftVersions.count) Minecraft versions"
            } catch {
                statusMessage = "Minecraft version refresh failed: \(OnlineContentErrorFormatter.displayMessage(for: error))"
            }
        }
    }

    func loadMinecraftPackage(for version: MinecraftRemoteVersion) {
        guard let backend else {
            statusMessage = "Core backend is not ready for Minecraft metadata."
            return
        }

        versionTask?.cancel()
        statusMessage = "Loading Minecraft version metadata via Core"
        versionTask = Task {
            do {
                selectedMinecraftPackage = try await backend.minecraftPackage(version)
                statusMessage = "Loaded metadata for \(version.id)"
            } catch {
                statusMessage = "Minecraft metadata load failed: \(OnlineContentErrorFormatter.displayMessage(for: error))"
            }
        }
    }

    func refreshLoaderMetadata(for minecraftVersion: String) {
        guard let backend else {
            statusMessage = "Core backend is not ready for loader metadata."
            return
        }

        statusMessage = "Refreshing loader metadata via Core"
        Task {
            do {
                let metadata = try await backend.loaderMetadata(minecraftVersion)
                loaderMetadata = Dictionary(grouping: metadata, by: \.source)
                statusMessage = "Loaded loader metadata for \(minecraftVersion)"
            } catch {
                loaderMetadata = [:]
                statusMessage = "Loader metadata refresh failed: \(OnlineContentErrorFormatter.displayMessage(for: error))"
            }
        }
    }

    func cancel() {
        searchTask?.cancel()
        projectTask?.cancel()
        versionTask?.cancel()
        isLoading = false
        statusMessage = "Online content request cancelled"
    }

    private func apiKey(for source: ContentSourceID) -> String? {
        guard source == .curseForge else { return nil }
        let result = credentials.curseForgeAPIKey(configured: curseForgeAPIKeyConfigured)
        if curseForgeAPIKeyConfigured != result.isConfigured {
            curseForgeAPIKeyConfigured = result.isConfigured
        }
        return result.value
    }
}
