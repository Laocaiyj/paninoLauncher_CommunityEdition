import Foundation

struct OnlineContentSearchBatchResult {
    private(set) var pages: [ContentSourceID: OnlineSearchPage] = [:]
    private(set) var failuresBySource: [ContentSourceID: String] = [:]
    private(set) var failureSnapshotsBySource: [ContentSourceID: String] = [:]
    private var failureMessages: [String] = []

    var succeeded: Bool {
        failuresBySource.isEmpty
    }

    var statusMessage: String {
        guard !failureMessages.isEmpty else {
            return "Loaded \(projectCount) online projects"
        }
        return failureMessages.joined(separator: " | ")
    }

    mutating func addPage(_ page: OnlineSearchPage, for source: ContentSourceID) {
        pages[source] = page
    }

    mutating func addFailure(_ error: Error, source: ContentSourceID, query: OnlineSearchQuery) {
        let message = OnlineContentErrorFormatter.displayMessage(for: error)
        failuresBySource[source] = message
        failureSnapshotsBySource[source] = query.diagnosticSummary(source: source)
        failureMessages.append("\(source.displayName): \(message)")
    }

    private var projectCount: Int {
        pages.values.reduce(0) { $0 + $1.projects.count }
    }
}
