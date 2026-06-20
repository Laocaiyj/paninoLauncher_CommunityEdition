import Foundation
import Combine

@MainActor
final class LauncherSettings: ObservableObject {
    static let defaultDownloadConcurrency = 32
    static let defaultDownloadRetryCount = 3
    static let downloadConcurrencyRange = 1...64
    static let downloadRetryCountRange = 0...10

    @Published var autoConnectCore = SettingsStore.bool(forKey: LauncherSettingsKey.autoConnectCore, default: true) {
        didSet { SettingsStore.set(autoConnectCore, forKey: LauncherSettingsKey.autoConnectCore) }
    }

    @Published var autoCheckUpdates = SettingsStore.bool(forKey: LauncherSettingsKey.autoCheckUpdates, default: true) {
        didSet { SettingsStore.set(autoCheckUpdates, forKey: LauncherSettingsKey.autoCheckUpdates) }
    }

    @Published var closeWindowBehavior: CloseWindowBehavior = LauncherSettings.loadEnum(
        key: LauncherSettingsKey.closeWindowBehavior,
        defaultValue: .quit
    ) {
        didSet { SettingsStore.set(closeWindowBehavior.rawValue, forKey: LauncherSettingsKey.closeWindowBehavior) }
    }

    @Published var defaultGameDirectory = SettingsStore.string(
        forKey: LauncherSettingsKey.defaultGameDirectory,
        default: LauncherSettings.defaultMinecraftDirectory
    ) {
        didSet { SettingsDebouncer.set(defaultGameDirectory, forKey: LauncherSettingsKey.defaultGameDirectory) }
    }

    @Published var windowWidth = LauncherSettings.integer(forKey: LauncherSettingsKey.windowWidth, defaultValue: 1280, range: 640...3840) {
        didSet { SettingsStore.set(String(windowWidth), forKey: LauncherSettingsKey.windowWidth) }
    }

    @Published var windowHeight = LauncherSettings.integer(forKey: LauncherSettingsKey.windowHeight, defaultValue: 720, range: 480...2160) {
        didSet { SettingsStore.set(String(windowHeight), forKey: LauncherSettingsKey.windowHeight) }
    }

    @Published var jvmArguments = SettingsStore.string(forKey: LauncherSettingsKey.jvmArguments, default: "") {
        didSet { SettingsDebouncer.set(jvmArguments, forKey: LauncherSettingsKey.jvmArguments) }
    }

    @Published var memoryPolicy: InstanceMemoryPolicy = LauncherSettings.storedMemoryPolicy() {
        didSet { SettingsStore.set(memoryPolicy.rawValue, forKey: LauncherSettingsKey.memoryPolicy) }
    }

    @Published var jvmProfile: InstanceJvmProfile = LauncherSettings.storedJvmProfile() {
        didSet { SettingsStore.set(jvmProfile.rawValue, forKey: LauncherSettingsKey.jvmProfile) }
    }

    @Published var graphicsProfile: InstanceGraphicsProfile = LauncherSettings.storedGraphicsProfile() {
        didSet { SettingsStore.set(graphicsProfile.rawValue, forKey: LauncherSettingsKey.graphicsProfile) }
    }

    @Published var performanceApplyMode: PerformanceApplyMode = LauncherSettings.storedPerformanceApplyMode() {
        didSet { SettingsStore.set(performanceApplyMode.rawValue, forKey: LauncherSettingsKey.performanceApplyMode) }
    }

    @Published var performanceLocalTelemetryEnabled = SettingsStore.bool(
        forKey: LauncherSettingsKey.performanceLocalTelemetryEnabled,
        default: true
    ) {
        didSet { SettingsStore.set(performanceLocalTelemetryEnabled, forKey: LauncherSettingsKey.performanceLocalTelemetryEnabled) }
    }

    @Published var performanceExperimentsEnabled = SettingsStore.bool(
        forKey: LauncherSettingsKey.performanceExperimentsEnabled,
        default: true
    ) {
        didSet { SettingsStore.set(performanceExperimentsEnabled, forKey: LauncherSettingsKey.performanceExperimentsEnabled) }
    }

    @Published var performanceShareAnonymousPriors = SettingsStore.bool(
        forKey: LauncherSettingsKey.performanceShareAnonymousPriors,
        default: false
    ) {
        didSet { SettingsStore.set(performanceShareAnonymousPriors, forKey: LauncherSettingsKey.performanceShareAnonymousPriors) }
    }

    @Published var installMissingFilesBeforeLaunch = SettingsStore.bool(
        forKey: LauncherSettingsKey.installMissingFilesBeforeLaunch,
        default: true
    ) {
        didSet { SettingsStore.set(installMissingFilesBeforeLaunch, forKey: LauncherSettingsKey.installMissingFilesBeforeLaunch) }
    }

    @Published var autoDetectJava = SettingsStore.bool(forKey: LauncherSettingsKey.autoDetectJava, default: true) {
        didSet { SettingsStore.set(autoDetectJava, forKey: LauncherSettingsKey.autoDetectJava) }
    }

    @Published var downloadStrategy: DownloadStrategy = LauncherSettings.storedDownloadStrategy() {
        didSet { SettingsStore.set(downloadStrategy.rawValue, forKey: LauncherSettingsKey.downloadStrategy) }
    }

    @Published var downloadConcurrency = LauncherSettings.integer(
        forKey: LauncherSettingsKey.downloadConcurrency,
        defaultValue: LauncherSettings.defaultDownloadConcurrency,
        range: LauncherSettings.downloadConcurrencyRange
    ) {
        didSet { SettingsStore.set(String(Self.clampedDownloadConcurrency(downloadConcurrency)), forKey: LauncherSettingsKey.downloadConcurrency) }
    }

    @Published var downloadRetryCount = LauncherSettings.integer(
        forKey: LauncherSettingsKey.downloadRetryCount,
        defaultValue: LauncherSettings.defaultDownloadRetryCount,
        range: LauncherSettings.downloadRetryCountRange
    ) {
        didSet { SettingsStore.set(String(Self.clampedDownloadRetryCount(downloadRetryCount)), forKey: LauncherSettingsKey.downloadRetryCount) }
    }

    @Published var proxyAddress = SettingsStore.string(forKey: LauncherSettingsKey.proxyAddress, default: "") {
        didSet { SettingsDebouncer.set(proxyAddress, forKey: LauncherSettingsKey.proxyAddress) }
    }

    @Published var downloadSource: DownloadSource = LauncherSettings.storedDownloadSource() {
        didSet { SettingsStore.set(downloadSource.rawValue, forKey: LauncherSettingsKey.downloadSource) }
    }

    @Published var autoSaveLogs = SettingsStore.bool(forKey: LauncherSettingsKey.autoSaveLogs, default: true) {
        didSet { SettingsStore.set(autoSaveLogs, forKey: LauncherSettingsKey.autoSaveLogs) }
    }

    @Published var logRetentionDays = LauncherSettings.integer(
        forKey: LauncherSettingsKey.logRetentionDays,
        defaultValue: 14,
        range: 1...365
    ) {
        didSet { SettingsStore.set(String(logRetentionDays), forKey: LauncherSettingsKey.logRetentionDays) }
    }

    @Published var advancedModeEnabled = SettingsStore.bool(forKey: LauncherSettingsKey.advancedModeEnabled, default: false) {
        didSet { SettingsStore.set(advancedModeEnabled, forKey: LauncherSettingsKey.advancedModeEnabled) }
    }

    @Published private(set) var cacheStatus = "Cache not checked"
    @Published private(set) var cacheSummaries: [CacheScopeSummary] = []

    init() {
        if SettingsStore.string(forKey: LauncherSettingsKey.downloadSource, default: DownloadSource.official.rawValue) == DownloadSource.custom.rawValue {
            SettingsStore.set(DownloadSource.official.rawValue, forKey: LauncherSettingsKey.downloadSource)
            downloadSource = .official
        }
        refreshCacheSummaries()
    }

    func clearDownloadCache() {
        clearCacheScopes([.downloadStaging], taskCenterStore: nil)
    }

    func refreshCacheSummaries() {
        cacheSummaries = LauncherCacheService.summaries()
        cacheStatus = LauncherCacheService.status(for: cacheSummaries)
    }

    func clearCacheScopes(_ scopes: Set<CacheScope>, taskCenterStore: TaskCenterStore?) {
        let result = LauncherCacheService.clear(scopes: scopes, previousSummaries: cacheSummaries)
        cacheSummaries = result.summariesAfter
        cacheStatus = result.status
        if result.failures.isEmpty {
            taskCenterStore?.upsertLocal(
                kind: "cache-cleanup",
                name: "Cache cleanup",
                state: .succeeded,
                progress: 1,
                currentFile: result.clearedDetails.joined(separator: "\n"),
                message: result.successMessage
            )
        } else {
            taskCenterStore?.upsertLocal(
                kind: "cache-cleanup",
                name: "Cache cleanup",
                state: .failed,
                progress: 1,
                errorCode: "cache_cleanup_failed",
                errorDetail: result.failures.joined(separator: "\n"),
                message: result.status
            )
        }
    }

}
