import Foundation

extension LauncherSettings {
    static var defaultMinecraftDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/minecraft", isDirectory: true)
            .path
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
}
