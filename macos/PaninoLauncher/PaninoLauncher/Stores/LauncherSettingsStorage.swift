import Foundation

enum LauncherSettingsKey {
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

extension LauncherSettings {
    static var defaultMinecraftDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/minecraft", isDirectory: true)
            .path
    }

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

    static func storedCloseWindowBehavior() -> CloseWindowBehavior {
        loadEnum(key: LauncherSettingsKey.closeWindowBehavior, defaultValue: .quit)
    }

    static func storedInstallMissingFilesBeforeLaunch() -> Bool {
        SettingsStore.bool(forKey: LauncherSettingsKey.installMissingFilesBeforeLaunch, default: true)
    }

    static func storedJVMArguments() -> [String] {
        shellSplit(SettingsStore.string(forKey: LauncherSettingsKey.jvmArguments, default: ""))
    }

    static func storedMemoryPolicy() -> InstanceMemoryPolicy {
        loadEnum(key: LauncherSettingsKey.memoryPolicy, defaultValue: .auto)
    }

    static func storedJvmProfile() -> InstanceJvmProfile {
        loadEnum(key: LauncherSettingsKey.jvmProfile, defaultValue: .auto)
    }

    static func storedGraphicsProfile() -> InstanceGraphicsProfile {
        loadEnum(key: LauncherSettingsKey.graphicsProfile, defaultValue: .balanced)
    }

    static func storedPerformanceApplyMode() -> PerformanceApplyMode {
        loadEnum(key: LauncherSettingsKey.performanceApplyMode, defaultValue: .ask)
    }

    static func storedPerformanceLocalTelemetryEnabled() -> Bool {
        SettingsStore.bool(forKey: LauncherSettingsKey.performanceLocalTelemetryEnabled, default: true)
    }

    static func storedPerformanceExperimentsEnabled() -> Bool {
        SettingsStore.bool(forKey: LauncherSettingsKey.performanceExperimentsEnabled, default: true)
    }

    static func storedPerformanceShareAnonymousPriors() -> Bool {
        SettingsStore.bool(forKey: LauncherSettingsKey.performanceShareAnonymousPriors, default: false)
    }

    static func storedWindowSize() -> (width: Int, height: Int) {
        (
            width: integer(forKey: LauncherSettingsKey.windowWidth, defaultValue: 1280, range: 640...3840),
            height: integer(forKey: LauncherSettingsKey.windowHeight, defaultValue: 720, range: 480...2160)
        )
    }

    static func integer(forKey key: String, defaultValue: Int, range: ClosedRange<Int>) -> Int {
        let rawValue = SettingsStore.string(forKey: key, default: String(defaultValue))
        let value = Int(rawValue) ?? defaultValue
        return min(max(value, range.lowerBound), range.upperBound)
    }

    static func clampedDownloadConcurrency(_ value: Int) -> Int {
        min(max(value, downloadConcurrencyRange.lowerBound), downloadConcurrencyRange.upperBound)
    }

    static func clampedDownloadRetryCount(_ value: Int) -> Int {
        min(max(value, downloadRetryCountRange.lowerBound), downloadRetryCountRange.upperBound)
    }

    static func loadEnum<Value: RawRepresentable>(
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
