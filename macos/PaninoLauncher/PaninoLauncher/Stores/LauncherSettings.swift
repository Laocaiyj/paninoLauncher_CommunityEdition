import Foundation
import SwiftUI

@MainActor
final class LauncherSettings: ObservableObject {
    static let defaultDownloadConcurrency = 32
    static let defaultDownloadRetryCount = 3
    static let downloadConcurrencyRange = 1...64
    static let downloadRetryCountRange = 0...10

    private enum Key {
        static let autoConnectCore = "Settings.AutoConnectCore"
        static let autoCheckUpdates = "Settings.AutoCheckUpdates"
        static let closeWindowBehavior = "Settings.CloseWindowBehavior"
        static let defaultGameDirectory = "Settings.DefaultGameDirectory"
        static let windowWidth = "Settings.WindowWidth"
        static let windowHeight = "Settings.WindowHeight"
        static let jvmArguments = "Settings.JVMArguments"
        static let memoryPolicy = "Settings.MemoryPolicy"
        static let jvmProfile = "Settings.JVMProfile"
        static let graphicsProfile = "Settings.GraphicsProfile"
        static let performanceApplyMode = "Settings.PerformanceApplyMode"
        static let performanceLocalTelemetryEnabled = "Settings.PerformanceLocalTelemetryEnabled"
        static let performanceExperimentsEnabled = "Settings.PerformanceExperimentsEnabled"
        static let performanceShareAnonymousPriors = "Settings.PerformanceShareAnonymousPriors"
        static let installMissingFilesBeforeLaunch = "Settings.InstallMissingFilesBeforeLaunch"
        static let autoDetectJava = "Settings.AutoDetectJava"
        static let downloadStrategy = "Settings.DownloadStrategy"
        static let downloadConcurrency = "Settings.DownloadConcurrency"
        static let downloadRetryCount = "Settings.DownloadRetryCount"
        static let proxyAddress = "Settings.ProxyAddress"
        static let downloadSource = "Settings.DownloadSource"
        static let autoSaveLogs = "Settings.AutoSaveLogs"
        static let logRetentionDays = "Settings.LogRetentionDays"
        static let advancedModeEnabled = "Settings.AdvancedModeEnabled"
    }

    @Published var autoConnectCore = SettingsStore.bool(forKey: Key.autoConnectCore, default: true) {
        didSet { SettingsStore.set(autoConnectCore, forKey: Key.autoConnectCore) }
    }

    @Published var autoCheckUpdates = SettingsStore.bool(forKey: Key.autoCheckUpdates, default: true) {
        didSet { SettingsStore.set(autoCheckUpdates, forKey: Key.autoCheckUpdates) }
    }

    @Published var closeWindowBehavior: CloseWindowBehavior = LauncherSettings.loadEnum(
        key: Key.closeWindowBehavior,
        defaultValue: .quit
    ) {
        didSet { SettingsStore.set(closeWindowBehavior.rawValue, forKey: Key.closeWindowBehavior) }
    }

    @Published var defaultGameDirectory = SettingsStore.string(
        forKey: Key.defaultGameDirectory,
        default: LauncherSettings.defaultMinecraftDirectory
    ) {
        didSet { SettingsDebouncer.set(defaultGameDirectory, forKey: Key.defaultGameDirectory) }
    }

    @Published var windowWidth = LauncherSettings.integer(forKey: Key.windowWidth, defaultValue: 1280, range: 640...3840) {
        didSet { SettingsStore.set(String(windowWidth), forKey: Key.windowWidth) }
    }

    @Published var windowHeight = LauncherSettings.integer(forKey: Key.windowHeight, defaultValue: 720, range: 480...2160) {
        didSet { SettingsStore.set(String(windowHeight), forKey: Key.windowHeight) }
    }

    @Published var jvmArguments = SettingsStore.string(forKey: Key.jvmArguments, default: "") {
        didSet { SettingsDebouncer.set(jvmArguments, forKey: Key.jvmArguments) }
    }

    @Published var memoryPolicy: InstanceMemoryPolicy = LauncherSettings.storedMemoryPolicy() {
        didSet { SettingsStore.set(memoryPolicy.rawValue, forKey: Key.memoryPolicy) }
    }

    @Published var jvmProfile: InstanceJvmProfile = LauncherSettings.storedJvmProfile() {
        didSet { SettingsStore.set(jvmProfile.rawValue, forKey: Key.jvmProfile) }
    }

    @Published var graphicsProfile: InstanceGraphicsProfile = LauncherSettings.storedGraphicsProfile() {
        didSet { SettingsStore.set(graphicsProfile.rawValue, forKey: Key.graphicsProfile) }
    }

    @Published var performanceApplyMode: PerformanceApplyMode = LauncherSettings.storedPerformanceApplyMode() {
        didSet { SettingsStore.set(performanceApplyMode.rawValue, forKey: Key.performanceApplyMode) }
    }

    @Published var performanceLocalTelemetryEnabled = SettingsStore.bool(
        forKey: Key.performanceLocalTelemetryEnabled,
        default: true
    ) {
        didSet { SettingsStore.set(performanceLocalTelemetryEnabled, forKey: Key.performanceLocalTelemetryEnabled) }
    }

    @Published var performanceExperimentsEnabled = SettingsStore.bool(
        forKey: Key.performanceExperimentsEnabled,
        default: true
    ) {
        didSet { SettingsStore.set(performanceExperimentsEnabled, forKey: Key.performanceExperimentsEnabled) }
    }

    @Published var performanceShareAnonymousPriors = SettingsStore.bool(
        forKey: Key.performanceShareAnonymousPriors,
        default: false
    ) {
        didSet { SettingsStore.set(performanceShareAnonymousPriors, forKey: Key.performanceShareAnonymousPriors) }
    }

    @Published var installMissingFilesBeforeLaunch = SettingsStore.bool(
        forKey: Key.installMissingFilesBeforeLaunch,
        default: true
    ) {
        didSet { SettingsStore.set(installMissingFilesBeforeLaunch, forKey: Key.installMissingFilesBeforeLaunch) }
    }

    @Published var autoDetectJava = SettingsStore.bool(forKey: Key.autoDetectJava, default: true) {
        didSet { SettingsStore.set(autoDetectJava, forKey: Key.autoDetectJava) }
    }

    @Published var downloadStrategy: DownloadStrategy = LauncherSettings.storedDownloadStrategy() {
        didSet { SettingsStore.set(downloadStrategy.rawValue, forKey: Key.downloadStrategy) }
    }

    @Published var downloadConcurrency = LauncherSettings.integer(
        forKey: Key.downloadConcurrency,
        defaultValue: LauncherSettings.defaultDownloadConcurrency,
        range: LauncherSettings.downloadConcurrencyRange
    ) {
        didSet { SettingsStore.set(String(Self.clampedDownloadConcurrency(downloadConcurrency)), forKey: Key.downloadConcurrency) }
    }

    @Published var downloadRetryCount = LauncherSettings.integer(
        forKey: Key.downloadRetryCount,
        defaultValue: LauncherSettings.defaultDownloadRetryCount,
        range: LauncherSettings.downloadRetryCountRange
    ) {
        didSet { SettingsStore.set(String(Self.clampedDownloadRetryCount(downloadRetryCount)), forKey: Key.downloadRetryCount) }
    }

    @Published var proxyAddress = SettingsStore.string(forKey: Key.proxyAddress, default: "") {
        didSet { SettingsDebouncer.set(proxyAddress, forKey: Key.proxyAddress) }
    }

    @Published var downloadSource: DownloadSource = LauncherSettings.storedDownloadSource() {
        didSet { SettingsStore.set(downloadSource.rawValue, forKey: Key.downloadSource) }
    }

    @Published var autoSaveLogs = SettingsStore.bool(forKey: Key.autoSaveLogs, default: true) {
        didSet { SettingsStore.set(autoSaveLogs, forKey: Key.autoSaveLogs) }
    }

    @Published var logRetentionDays = LauncherSettings.integer(
        forKey: Key.logRetentionDays,
        defaultValue: 14,
        range: 1...365
    ) {
        didSet { SettingsStore.set(String(logRetentionDays), forKey: Key.logRetentionDays) }
    }

    @Published var advancedModeEnabled = SettingsStore.bool(forKey: Key.advancedModeEnabled, default: false) {
        didSet { SettingsStore.set(advancedModeEnabled, forKey: Key.advancedModeEnabled) }
    }

    @Published private(set) var cacheStatus = "Cache not checked"
    @Published private(set) var cacheSummaries: [CacheScopeSummary] = []

    init() {
        if SettingsStore.string(forKey: Key.downloadSource, default: DownloadSource.official.rawValue) == DownloadSource.custom.rawValue {
            SettingsStore.set(DownloadSource.official.rawValue, forKey: Key.downloadSource)
            downloadSource = .official
        }
        refreshCacheSummaries()
    }

    func clearDownloadCache() {
        clearCacheScopes([.downloadStaging], taskCenterStore: nil)
    }

    func refreshCacheSummaries() {
        cacheSummaries = CacheScope.allCases.map { scope in
            let target = cacheTarget(for: scope)
            return CacheScopeSummary(
                scope: scope,
                path: target.path,
                exists: target.exists,
                bytes: cacheSize(for: scope, target: target)
            )
        }
        cacheStatus = cacheSummaries.isEmpty
            ? "Cache not checked"
            : "Estimated cache size \(Self.formatBytes(cacheSummaries.compactMap(\.bytes).reduce(0, +)))"
    }

    func clearCacheScopes(_ scopes: Set<CacheScope>, taskCenterStore: TaskCenterStore?) {
        let summariesBefore = Dictionary(uniqueKeysWithValues: cacheSummaries.map { ($0.scope, $0) })
        let before = cacheSummaries.compactMap(\.bytes).reduce(0, +)
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

        refreshCacheSummaries()
        let after = cacheSummaries.compactMap(\.bytes).reduce(0, +)
        let deleted = max(before - after, 0)
        let deletedDetails = cleared.map { scope in
            let summary = summariesBefore[scope]
            let size = Self.formatBytes(summary?.bytes ?? 0)
            return "\(scope.title): \(summary?.path ?? "-") (\(size))"
        }
        if failures.isEmpty {
            cacheStatus = cleared.isEmpty
                ? "No cache scope selected"
                : "Cleared \(cleared.map(\.title).joined(separator: ", ")); freed about \(Self.formatBytes(deleted))"
            taskCenterStore?.upsertLocal(
                kind: "cache-cleanup",
                name: "Cache cleanup",
                state: .succeeded,
                progress: 1,
                currentFile: deletedDetails.joined(separator: "\n"),
                message: "\(cacheStatus)\n\(deletedDetails.joined(separator: "\n"))"
            )
        } else {
            cacheStatus = "Cache cleanup failed: \(failures.joined(separator: "; "))"
            taskCenterStore?.upsertLocal(
                kind: "cache-cleanup",
                name: "Cache cleanup",
                state: .failed,
                progress: 1,
                errorCode: "cache_cleanup_failed",
                errorDetail: failures.joined(separator: "\n"),
                message: cacheStatus
            )
        }
    }

    static func javaRecommendation(for minecraftVersion: String) -> String {
        let normalized = minecraftVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let version = MinecraftVersionNumber(normalized) else {
            return "Select a Minecraft version to calculate the Java recommendation from its release family."
        }

        if version >= MinecraftVersionNumber(1, 20, 5) {
            return "Minecraft \(normalized) recommends Java 21."
        }
        if version >= MinecraftVersionNumber(1, 18, 0) {
            return "Minecraft \(normalized) recommends Java 17."
        }
        if version >= MinecraftVersionNumber(1, 17, 0) {
            return "Minecraft \(normalized) recommends Java 16."
        }
        return "Minecraft \(normalized) generally uses Java 8."
    }

    private func clearCacheScope(_ scope: CacheScope) throws {
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

    private func cacheTarget(for scope: CacheScope) -> (path: String, exists: Bool) {
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

    private func cacheSize(for scope: CacheScope, target: (path: String, exists: Bool)) -> Int64? {
        switch scope {
        case .urlCache:
            return Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage)
        case .downloadStaging, .metadataHttp, .verificationIndex:
            guard target.exists else { return 0 }
            return Self.fileSize(at: URL(fileURLWithPath: target.path))
        }
    }

    static func storedDownloadConcurrency() -> Int {
        integer(
            forKey: Key.downloadConcurrency,
            defaultValue: defaultDownloadConcurrency,
            range: downloadConcurrencyRange
        )
    }

    static func storedDownloadRetryCount() -> Int {
        integer(
            forKey: Key.downloadRetryCount,
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
        loadEnum(key: Key.downloadStrategy, defaultValue: .auto)
    }

    static func storedDownloadSource() -> DownloadSource {
        let source: DownloadSource = loadEnum(key: Key.downloadSource, defaultValue: .official)
        return source == .custom ? .official : source
    }

    static func storedCloseWindowBehavior() -> CloseWindowBehavior {
        loadEnum(key: Key.closeWindowBehavior, defaultValue: .quit)
    }

    static func storedInstallMissingFilesBeforeLaunch() -> Bool {
        SettingsStore.bool(forKey: Key.installMissingFilesBeforeLaunch, default: true)
    }

    static func storedJVMArguments() -> [String] {
        shellSplit(SettingsStore.string(forKey: Key.jvmArguments, default: ""))
    }

    static func storedMemoryPolicy() -> InstanceMemoryPolicy {
        loadEnum(key: Key.memoryPolicy, defaultValue: .auto)
    }

    static func storedJvmProfile() -> InstanceJvmProfile {
        loadEnum(key: Key.jvmProfile, defaultValue: .auto)
    }

    static func storedGraphicsProfile() -> InstanceGraphicsProfile {
        loadEnum(key: Key.graphicsProfile, defaultValue: .balanced)
    }

    static func storedPerformanceApplyMode() -> PerformanceApplyMode {
        loadEnum(key: Key.performanceApplyMode, defaultValue: .ask)
    }

    static func storedPerformanceLocalTelemetryEnabled() -> Bool {
        SettingsStore.bool(forKey: Key.performanceLocalTelemetryEnabled, default: true)
    }

    static func storedPerformanceExperimentsEnabled() -> Bool {
        SettingsStore.bool(forKey: Key.performanceExperimentsEnabled, default: true)
    }

    static func storedPerformanceShareAnonymousPriors() -> Bool {
        SettingsStore.bool(forKey: Key.performanceShareAnonymousPriors, default: false)
    }

    static func storedWindowSize() -> (width: Int, height: Int) {
        (
            width: integer(forKey: Key.windowWidth, defaultValue: 1280, range: 640...3840),
            height: integer(forKey: Key.windowHeight, defaultValue: 720, range: 480...2160)
        )
    }

    static var defaultMinecraftDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/minecraft", isDirectory: true)
            .path
    }

    private static func integer(forKey key: String, defaultValue: Int, range: ClosedRange<Int>) -> Int {
        let rawValue = SettingsStore.string(forKey: key, default: String(defaultValue))
        let value = Int(rawValue) ?? defaultValue
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clampedDownloadConcurrency(_ value: Int) -> Int {
        min(max(value, downloadConcurrencyRange.lowerBound), downloadConcurrencyRange.upperBound)
    }

    private static func clampedDownloadRetryCount(_ value: Int) -> Int {
        min(max(value, downloadRetryCountRange.lowerBound), downloadRetryCountRange.upperBound)
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

    private static func loadEnum<Value: RawRepresentable>(
        key: String,
        defaultValue: Value
    ) -> Value where Value.RawValue == String {
        let rawValue = SettingsStore.string(forKey: key, default: defaultValue.rawValue)
        return Value(rawValue: rawValue) ?? defaultValue
    }

    private static func shellSplit(_ value: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false

        for character in value {
            if escaping {
                current.append(character)
                escaping = false
                continue
            }

            if character == "\\" {
                escaping = true
                continue
            }

            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if escaping {
            current.append("\\")
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}

private struct MinecraftVersionNumber: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ rawValue: String) {
        let numberPrefix = rawValue.prefix { character in
            character.isNumber || character == "."
        }
        let parts = numberPrefix.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        major = parts[0]
        minor = parts[1]
        patch = parts.count > 2 ? parts[2] : 0
    }

    static func < (lhs: MinecraftVersionNumber, rhs: MinecraftVersionNumber) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
