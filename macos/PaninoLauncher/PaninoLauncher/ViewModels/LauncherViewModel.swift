import Foundation

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var coreState: CoreConnectionState = .stopped
    @Published var version = "1.20.1"
    @Published var memoryMb = SettingsStore.memoryMb {
        didSet {
            SettingsStore.memoryMb = memoryMb
        }
    }
    @Published var javaPath = SettingsStore.javaPath {
        didSet {
            SettingsDebouncer.set(javaPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "JavaPath")
        }
    }
    @Published var javaStatus: JavaRuntimeStatus?
    @Published var discoveredJavaRuntimes: [JavaRuntimeCandidate] = []
    @Published var javaScanStatus = "Java runtimes not scanned"
    @Published var javaRuntimeResolution: CoreJavaRuntimeResolveResponse?
    @Published var managedJavaRuntimes: [CoreJavaManagedRuntime] = []
    @Published var managedJavaRoot = ""
    @Published var javaRuntimeStatus = "Java runtime manager not loaded"
    @Published var lastExportedLogURL: URL?
    @Published var currentTask: TaskSnapshot?
    @Published var currentTaskProgress: TaskProgress?
    @Published var latestCoreEvent: CoreEvent?
    @Published var lastTaskFailure: TaskSnapshot?
    @Published var lastInstallPreflight: CoreLoaderInstallPreflightResponse?
    @Published var logs: [LogLine] = []
    @Published var microsoftClientId: String = SettingsStore.microsoftClientId {
        didSet {
            SettingsDebouncer.set(microsoftClientId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "MicrosoftClientID")
        }
    }
    @Published var accountState: AccountConnectionState = .signedOut

    let processManager = CoreProcessManager()
    let authService = MicrosoftAuthService()
    var apiClient: LauncherApiClient?
    var eventTask: Task<Void, Never>?
    var taskPoller: Task<Void, Never>?
    var authTask: Task<Void, Never>?
    var javaCheckTask: Task<Void, Never>?
    var javaScanTask: Task<Void, Never>?
    var javaRuntimeTask: Task<Void, Never>?
    var pendingJavaRuntimeLaunch: PendingJavaRuntimeLaunch?
    var coreStartTask: Task<Void, Never>?
    var submissionTask: Task<Void, Never>?
    var cancelTask: Task<Void, Never>?
    var logExportTask: Task<Void, Never>?
    var eventLogFlushTask: Task<Void, Never>?
    var pendingEventLog: (text: String, source: LogSource)?
    var lastEventLogAt = Date.distantPast
    var expectedCoreStop = false
    var coreRestartAttempts = 0

    var canSubmitTask: Bool {
        canStartTaskSubmission && currentTask?.state.isActive != true
    }

    var canStartTaskSubmission: Bool {
        coreState != .starting
            && coreState != .stopping
            && submissionTask == nil
    }

    func canLaunch(gameDir: String?) -> Bool {
        guard canStartTaskSubmission else { return false }
        guard let activeTask = currentTask, activeTask.state.isActive else { return true }
        guard activeTask.kind != "launch" else { return false }
        guard let activeGameDir = sanitizedGameDir(activeTask.gameDir),
              let requestedGameDir = sanitizedGameDir(gameDir) else {
            return false
        }
        return !Self.sameFilePath(activeGameDir, requestedGameDir)
    }

    var canCancelTask: Bool {
        coreState.isReady && currentTask?.state.isActive == true || submissionTask != nil || logExportTask != nil
    }

    var statusText: String {
        if let currentTask {
            let errorCode = currentTask.errorCode.map { " [\($0)]" } ?? ""
            return "\(currentTask.kind.capitalized) \(currentTask.state.rawValue)\(errorCode): \(currentTask.diagnostic?.userSummary ?? currentTask.message ?? currentTask.version)"
        }
        return coreState.detail
    }

    var progressLabel: String {
        guard let currentTask else { return "Idle" }
        if let errorCode = currentTask.errorCode {
            return "\(currentTask.kind.capitalized) \(currentTask.version) - \(currentTask.state.rawValue) (\(errorCode))"
        }
        return "\(currentTask.kind.capitalized) \(currentTask.version) - \(currentTask.state.rawValue)"
    }

    var canStartLogin: Bool {
        !microsoftClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func sameFilePath(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }
}

struct PendingJavaRuntimeLaunch: Equatable {
    let taskId: String
    let version: String
    let accountID: String?
    let gameDir: String
    let instance: GameInstance?
}
