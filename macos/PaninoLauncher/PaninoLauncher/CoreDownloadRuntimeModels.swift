import Foundation

struct CoreDownloadRuntimeOptions: Codable, Equatable, Sendable {
    let concurrency: Int
    let retryCount: Int
    let strategy: String?

    init(concurrency: Int, retryCount: Int, strategy: String? = nil) {
        self.concurrency = concurrency
        self.retryCount = retryCount
        self.strategy = strategy
    }
}
