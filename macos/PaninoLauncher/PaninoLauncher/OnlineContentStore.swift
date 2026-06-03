import Foundation

@MainActor
struct OnlineContentCoreBackend {
    let search: (OnlineSearchQuery, ContentSourceID, String?) async throws -> OnlineSearchPage
    let project: (String, ContentSourceID, OnlineSearchQuery, String?) async throws -> CoreContentProjectResponse
    let minecraftVersions: () async throws -> [MinecraftRemoteVersion]
    let minecraftPackage: (MinecraftRemoteVersion) async throws -> MinecraftVersionPackage
    let loaderMetadata: (String) async throws -> [LoaderMetadata]
}

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

    private let secretStore = SecureSecretStore()
    private var backend: OnlineContentCoreBackend?
    private var searchTask: Task<Void, Never>?
    private var projectTask: Task<Void, Never>?
    private var versionTask: Task<Void, Never>?
    private var searchGeneration = 0
    private var projectGeneration = 0

    init() {
        curseForgeAPIKeyConfigured = UserDefaults.standard.bool(forKey: Self.curseForgeAPIKeyConfiguredKey)
    }

    func configure(coreBackend: OnlineContentCoreBackend) {
        backend = coreBackend
    }

    func hasCurseForgeAPIKey() -> Bool {
        curseForgeAPIKeyConfigured
    }

    func saveCurseForgeAPIKey(_ value: String) {
        do {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try secretStore.delete(.curseForgeAPIKey)
                setCurseForgeAPIKeyConfigured(false)
                statusMessage = "CurseForge API key removed"
            } else {
                try secretStore.save(trimmed, for: .curseForgeAPIKey)
                setCurseForgeAPIKeyConfigured(true)
                statusMessage = "CurseForge API key saved in Keychain"
            }
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
            var pages: [ContentSourceID: OnlineSearchPage] = [:]
            var failures: [String] = []
            var failuresBySource: [ContentSourceID: String] = [:]
            var failureSnapshotsBySource: [ContentSourceID: String] = [:]

            for source in requestedSources {
                guard !Task.isCancelled else { return }
                do {
                    pages[source] = try await backend.search(query, source, apiKey(for: source))
                } catch {
                    let message = Self.displayMessage(for: error)
                    failuresBySource[source] = message
                    failureSnapshotsBySource[source] = query.diagnosticSummary(source: source)
                    failures.append("\(source.displayName): \(message)")
                }
            }

            guard !Task.isCancelled, generation == searchGeneration else { return }
            for source in requestedSources {
                if let page = pages[source] {
                    searchResults[source] = page
                }
                if let failure = failuresBySource[source] {
                    searchFailures[source] = failure
                    searchFailureSnapshots[source] = failureSnapshotsBySource[source]
                } else {
                    searchFailures.removeValue(forKey: source)
                    searchFailureSnapshots.removeValue(forKey: source)
                }
            }
            isLoading = false
            if !pages.isEmpty {
                lastSearchUpdatedAt = Date()
            }
            statusMessage = failures.isEmpty
                ? "Loaded \(pages.values.reduce(0) { $0 + $1.projects.count }) online projects"
                : failures.joined(separator: " | ")
            completion?(failuresBySource.isEmpty)
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
                let message = Self.displayMessage(for: error)
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
                statusMessage = "Minecraft version refresh failed: \(Self.displayMessage(for: error))"
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
                statusMessage = "Minecraft metadata load failed: \(Self.displayMessage(for: error))"
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
                statusMessage = "Loader metadata refresh failed: \(Self.displayMessage(for: error))"
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
        guard curseForgeAPIKeyConfigured else { return nil }
        let value = (try? secretStore.load(.curseForgeAPIKey))?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            setCurseForgeAPIKeyConfigured(false)
            return nil
        }
        return value
    }

    private func setCurseForgeAPIKeyConfigured(_ configured: Bool) {
        curseForgeAPIKeyConfigured = configured
        UserDefaults.standard.set(configured, forKey: Self.curseForgeAPIKeyConfiguredKey)
    }

    private static func displayMessage(for error: Error) -> String {
        if case LauncherApiError.unexpectedStatus(_, let body) = error,
           let data = body.data(using: .utf8),
           let payload = try? JSONDecoder().decode(CoreErrorPayload.self, from: data) {
            if let details = payload.details, !details.isEmpty {
                return details
            }
            if let message = payload.message, !message.isEmpty {
                return message
            }
        }
        return error.localizedDescription
    }

    private static let curseForgeAPIKeyConfiguredKey = "OnlineContent.CurseForgeAPIKeyConfigured"
}

private struct CoreErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
}
