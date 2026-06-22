import Foundation

enum OnlineContentSearchRequestRunner {
    @MainActor
    static func run(
        query: OnlineSearchQuery,
        sources: [ContentSourceID],
        backend: OnlineContentCoreBackend,
        apiKey: (ContentSourceID) -> String?
    ) async -> OnlineContentSearchBatchResult {
        var batch = OnlineContentSearchBatchResult()

        for source in sources {
            guard !Task.isCancelled else { return batch }
            do {
                let page = try await backend.search(query, source, apiKey(source))
                batch.addPage(page, for: source)
            } catch {
                batch.addFailure(error, source: source, query: query)
            }
        }

        return batch
    }
}
