import Foundation

@MainActor
final class OnlineContentStore: ObservableObject {
    @Published private var searchState = OnlineContentStoreSearchState()
    @Published private var projectState = OnlineContentStoreProjectState()
    @Published private(set) var minecraftVersions: [MinecraftRemoteVersion] = []
    @Published private(set) var selectedMinecraftPackage: MinecraftVersionPackage?
    @Published private(set) var loaderMetadata: [ContentSourceID: [LoaderMetadata]] = [:]
    @Published private(set) var statusMessage = "Online content not loaded"
    @Published private(set) var isLoading = false
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

    var searchResults: [ContentSourceID: OnlineSearchPage] {
        searchState.results
    }

    var selectedProject: OnlineProject? {
        projectState.selectedProject
    }

    var selectedReleases: [OnlineRelease] {
        projectState.releases
    }

    var searchFailures: [ContentSourceID: String] {
        searchState.failures
    }

    var searchFailureSnapshots: [ContentSourceID: String] {
        searchState.failureSnapshots
    }

    var projectFailure: String? {
        projectState.failure
    }

    var lastSearchUpdatedAt: Date? {
        searchState.lastUpdatedAt
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
        searchState.clear(source: source)
        projectState.clear(for: source)
        statusMessage = "\(source.displayName) requires API credentials before browsing."
    }

    func selectProjectPreview(_ project: OnlineProject) {
        projectTask?.cancel()
        projectState.preview(project)
        statusMessage = "Loading \(project.title)"
    }

    func clearSelection(for source: ContentSourceID? = nil) {
        projectTask?.cancel()
        projectState.clear(for: source)
    }

    func search(
        _ query: OnlineSearchQuery,
        sources requestedSources: [ContentSourceID] = [.modrinth],
        clearExisting: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let backend = requireBackend("Core backend is not ready for online content.") else {
            completion?(false)
            return
        }

        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        isLoading = true
        statusMessage = "Searching online content via Core"
        searchState.clearFailures(for: requestedSources)
        if clearExisting {
            clearSelection()
        }
        projectState.beginLoad()

        searchTask = Task {
            let batch = await OnlineContentSearchRequestRunner.run(
                query: query,
                sources: requestedSources,
                backend: backend,
                apiKey: { apiKey(for: $0) }
            )

            guard !Task.isCancelled, generation == searchGeneration else { return }
            searchState.apply(batch, for: requestedSources, updatedAt: Date())
            isLoading = false
            statusMessage = batch.statusMessage
            completion?(batch.succeeded)
        }
    }

    func loadProject(_ projectID: String, sourceID: ContentSourceID, query: OnlineSearchQuery = OnlineSearchQuery()) {
        guard let backend = requireBackend("Core backend is not ready for project details.") else { return }

        projectTask?.cancel()
        projectGeneration += 1
        let generation = projectGeneration
        isLoading = true
        statusMessage = "Loading project details via Core"
        projectState.beginLoad()

        projectTask = Task {
            do {
                let response = try await backend.project(projectID, sourceID, query, apiKey(for: sourceID))
                guard !Task.isCancelled, generation == projectGeneration else { return }
                projectState.apply(response)
                statusMessage = "Loaded \(response.project.title)"
            } catch {
                guard !Task.isCancelled, generation == projectGeneration else { return }
                let message = OnlineContentErrorFormatter.displayMessage(for: error)
                projectState.fail(with: message)
                statusMessage = "Project load failed: \(message)"
            }
            guard !Task.isCancelled, generation == projectGeneration else { return }
            isLoading = false
        }
    }

    func refreshMinecraftVersions() {
        guard let backend = requireBackend("Core backend is not ready for Minecraft versions.") else { return }

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
        guard let backend = requireBackend("Core backend is not ready for Minecraft metadata.") else { return }

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
        guard let backend = requireBackend("Core backend is not ready for loader metadata.") else { return }

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

    private func requireBackend(_ unavailableMessage: String) -> OnlineContentCoreBackend? {
        guard let backend else {
            statusMessage = unavailableMessage
            return nil
        }
        return backend
    }
}
