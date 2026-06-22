import Foundation

struct OnlineContentStoreSearchState {
    private(set) var results: [ContentSourceID: OnlineSearchPage] = [:]
    private(set) var failures: [ContentSourceID: String] = [:]
    private(set) var failureSnapshots: [ContentSourceID: String] = [:]
    private(set) var lastUpdatedAt: Date?

    mutating func clear(source: ContentSourceID) {
        results.removeValue(forKey: source)
        clearFailures(for: [source])
    }

    mutating func clearFailures(for sources: [ContentSourceID]) {
        for source in sources {
            failures.removeValue(forKey: source)
            failureSnapshots.removeValue(forKey: source)
        }
    }

    mutating func apply(
        _ batch: OnlineContentSearchBatchResult,
        for sources: [ContentSourceID],
        updatedAt: Date
    ) {
        for source in sources {
            if let page = batch.pages[source] {
                results[source] = page
            }

            if let failure = batch.failuresBySource[source] {
                failures[source] = failure
                failureSnapshots[source] = batch.failureSnapshotsBySource[source]
            } else {
                failures.removeValue(forKey: source)
                failureSnapshots.removeValue(forKey: source)
            }
        }

        if !batch.pages.isEmpty {
            lastUpdatedAt = updatedAt
        }
    }
}

struct OnlineContentStoreProjectState {
    private(set) var selectedProject: OnlineProject?
    private(set) var releases: [OnlineRelease] = []
    private(set) var failure: String?

    mutating func preview(_ project: OnlineProject) {
        selectedProject = project
        releases = []
        failure = nil
    }

    mutating func clear(for source: ContentSourceID? = nil) {
        guard source == nil || selectedProject?.source == source else { return }
        selectedProject = nil
        releases = []
        failure = nil
    }

    mutating func beginLoad() {
        failure = nil
    }

    mutating func apply(_ response: CoreContentProjectResponse) {
        selectedProject = response.project
        releases = response.releases
        failure = nil
    }

    mutating func fail(with message: String) {
        failure = message
    }
}
