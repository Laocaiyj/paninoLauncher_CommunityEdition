import Foundation

extension LauncherSettings {
    static func storedDownloadConcurrency() -> Int {
        integer(
            forKey: LauncherSettingsKey.downloadConcurrency,
            defaultValue: defaultDownloadConcurrency,
            range: downloadConcurrencyRange
        )
    }

    static func storedDownloadRetryCount() -> Int {
        integer(
            forKey: LauncherSettingsKey.downloadRetryCount,
            defaultValue: defaultDownloadRetryCount,
            range: downloadRetryCountRange
        )
    }

    static func storedDownloadRuntimeOptions() -> CoreDownloadRuntimeOptions {
        let strategy = storedDownloadStrategy()
        let storedConcurrency = storedDownloadConcurrency()
        let storedRetryCount = storedDownloadRetryCount()
        let effectiveConcurrency: Int
        let effectiveRetryCount: Int

        switch strategy {
        case .auto:
            effectiveConcurrency = storedConcurrency
            effectiveRetryCount = storedRetryCount
        case .fast:
            effectiveConcurrency = min(downloadConcurrencyRange.upperBound, max(storedConcurrency, 48))
            effectiveRetryCount = min(downloadRetryCountRange.upperBound, max(storedRetryCount, 4))
        case .conservative:
            effectiveConcurrency = max(downloadConcurrencyRange.lowerBound, min(storedConcurrency, 12))
            effectiveRetryCount = min(downloadRetryCountRange.upperBound, max(storedRetryCount, 2))
        }

        return CoreDownloadRuntimeOptions(
            concurrency: effectiveConcurrency,
            retryCount: effectiveRetryCount,
            strategy: strategy.rawValue
        )
    }

    static func storedDownloadStrategy() -> DownloadStrategy {
        loadEnum(key: LauncherSettingsKey.downloadStrategy, defaultValue: .auto)
    }

    static func storedDownloadSource() -> DownloadSource {
        let source: DownloadSource = loadEnum(key: LauncherSettingsKey.downloadSource, defaultValue: .official)
        return source == .custom ? .official : source
    }

    static func clampedDownloadConcurrency(_ value: Int) -> Int {
        min(max(value, downloadConcurrencyRange.lowerBound), downloadConcurrencyRange.upperBound)
    }

    static func clampedDownloadRetryCount(_ value: Int) -> Int {
        min(max(value, downloadRetryCountRange.lowerBound), downloadRetryCountRange.upperBound)
    }
}
