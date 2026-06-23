import Foundation

struct LauncherCacheCleanupResult {
    let status: String
    let summariesAfter: [CacheScopeSummary]
    let clearedDetails: [String]
    let failures: [String]

    var successMessage: String {
        "\(status)\n\(clearedDetails.joined(separator: "\n"))"
    }
}

enum LauncherCacheService {
    static func summaries() -> [CacheScopeSummary] {
        CacheScope.allCases.map { scope in
            let target = cacheTarget(for: scope)
            return CacheScopeSummary(
                scope: scope,
                path: target.path,
                exists: target.exists,
                bytes: cacheSize(for: scope, target: target)
            )
        }
    }

    static func status(for summaries: [CacheScopeSummary]) -> String {
        summaries.isEmpty
            ? "Cache not checked"
            : "Estimated cache size \(formatBytes(summaries.compactMap(\.bytes).reduce(0, +)))"
    }

    static func clear(scopes: Set<CacheScope>, previousSummaries: [CacheScopeSummary]) -> LauncherCacheCleanupResult {
        let summariesBefore = Dictionary(uniqueKeysWithValues: previousSummaries.map { ($0.scope, $0) })
        let before = previousSummaries.compactMap(\.bytes).reduce(0, +)
        var cleared: [CacheScope] = []
        var failures: [String] = []

        for scope in scopes {
            do {
                try clearCacheScope(scope)
                cleared.append(scope)
            } catch {
                failures.append("\(scope.title): \(error.localizedDescription)")
            }
        }

        let summariesAfter = summaries()
        let after = summariesAfter.compactMap(\.bytes).reduce(0, +)
        let deleted = max(before - after, 0)
        let clearedDetails = cleared.map { scope in
            let summary = summariesBefore[scope]
            let size = formatBytes(summary?.bytes ?? 0)
            return "\(scope.title): \(summary?.path ?? "-") (\(size))"
        }
        let status = failures.isEmpty
            ? successStatus(cleared: cleared, deleted: deleted)
            : "Cache cleanup failed: \(failures.joined(separator: "; "))"

        return LauncherCacheCleanupResult(
            status: status,
            summariesAfter: summariesAfter,
            clearedDetails: clearedDetails,
            failures: failures
        )
    }

    private static func successStatus(cleared: [CacheScope], deleted: Int64) -> String {
        cleared.isEmpty
            ? "No cache scope selected"
            : "Cleared \(cleared.map(\.title).joined(separator: ", ")); freed about \(formatBytes(deleted))"
    }

    private static func clearCacheScope(_ scope: CacheScope) throws {
        switch scope {
        case .urlCache:
            URLCache.shared.removeAllCachedResponses()
        case .downloadStaging, .metadataHttp:
            let target = cacheTarget(for: scope)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(atPath: target.path)
            }
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: target.path, isDirectory: true),
                withIntermediateDirectories: true
            )
        case .verificationIndex:
            let target = cacheTarget(for: scope)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(atPath: target.path)
            }
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: target.path).deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
    }

    private static func cacheTarget(for scope: CacheScope) -> (path: String, exists: Bool) {
        do {
            let appSupport = try LauncherPaths.appSupportDirectory()
            let url: URL
            switch scope {
            case .downloadStaging:
                url = appSupport.appendingPathComponent("DownloadCache", isDirectory: true)
            case .metadataHttp:
                url = appSupport.appendingPathComponent("cache/http", isDirectory: true)
            case .verificationIndex:
                url = appSupport.appendingPathComponent("cache/verification-index.json", isDirectory: false)
            case .urlCache:
                url = URL(fileURLWithPath: "URLCache.shared", isDirectory: false)
            }
            let exists = scope == .urlCache || FileManager.default.fileExists(atPath: url.path)
            return (url.path, exists)
        } catch {
            return ("-", false)
        }
    }

    private static func cacheSize(for scope: CacheScope, target: (path: String, exists: Bool)) -> Int64? {
        switch scope {
        case .urlCache:
            return Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage)
        case .downloadStaging, .metadataHttp, .verificationIndex:
            guard target.exists else { return 0 }
            return fileSize(at: URL(fileURLWithPath: target.path))
        }
    }

    private static func fileSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }
        if !isDirectory.boolValue {
            return fileByteCount(url)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += fileByteCount(fileURL)
        }
        return total
    }

    private static func fileByteCount(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true else { return 0 }
        return Int64(values?.fileSize ?? 0)
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
