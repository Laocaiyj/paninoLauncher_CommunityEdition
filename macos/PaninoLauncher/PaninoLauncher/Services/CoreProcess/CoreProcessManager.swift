import Foundation

@MainActor
final class CoreProcessManager {
    private var process: Process?
    private var outputPipe: Pipe?
    private var endpoint: CoreEndpoint?
    private var outputBuffer = CoreProcessOutputBuffer()
    private var lastTerminationStatus: Int32?
    private var managedExecutableURL: URL?
    private var managedStartedAt: Date?

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(
        onOutput: @escaping @MainActor (String) -> Void,
        onTermination: @escaping @MainActor (Int32) -> Void = { _ in }
    ) async throws -> CoreEndpoint {
        if let endpoint, isRunning {
            if shouldRestartForUpdatedExecutable(), let process {
                await CoreProcessStopper.stop(process, apiClient: LauncherApiClient(endpoint: endpoint))
                cleanupRunningProcessState()
                Self.removeManagedCoreRecord()
            } else {
                return endpoint
            }
        }

        Self.emergencyStopRecordedCore()

        lastTerminationStatus = nil
        let launchContext = try makeLaunchContext()
        let process = Process()
        let outputPipe = Pipe()
        configure(
            process,
            outputPipe: outputPipe,
            launchContext: launchContext,
            onOutput: onOutput,
            onTermination: onTermination
        )

        do {
            try process.run()
        } catch {
            Self.removeSessionTokenFile(launchContext.tokenFileURL)
            throw error
        }

        let startedAt = Date()
        do {
            try Self.recordManagedCoreProcess(
                launchContext.managedRecord(pid: process.processIdentifier, startedAt: startedAt)
            )
        } catch {
            Self.removeSessionTokenFile(launchContext.tokenFileURL)
            await CoreProcessStopper.stop(process, apiClient: nil)
            throw error
        }

        track(process, outputPipe: outputPipe, launchContext: launchContext, startedAt: startedAt)

        do {
            try await waitForCore(endpoint: launchContext.endpoint)
            Self.removeSessionTokenFile(launchContext.tokenFileURL)
            return launchContext.endpoint
        } catch {
            Self.removeSessionTokenFile(launchContext.tokenFileURL)
            await CoreProcessStopper.stop(process, apiClient: nil)
            Self.removeManagedCoreRecord()
            throw error
        }
    }

    func stop(using apiClient: LauncherApiClient?) async {
        guard let process else {
            Self.emergencyStopRecordedCore()
            return
        }
        await CoreProcessStopper.stop(process, apiClient: apiClient)

        cleanupRunningProcessState()
        Self.removeManagedCoreRecord()
    }

    func shouldRestartForUpdatedExecutable() -> Bool {
        guard isRunning,
              let managedExecutableURL,
              let managedStartedAt,
              let modifiedAt = try? managedExecutableURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return false
        }
        return modifiedAt > managedStartedAt.addingTimeInterval(0.25)
    }

    private func makeLaunchContext() throws -> CoreProcessLaunchContext {
        let executableURL = try findCoreExecutable()
        let port = try allocateLoopbackPort()
        let token = makeSessionToken()
        let tokenFileURL = try Self.createSessionTokenFile(token: token)
        return CoreProcessLaunchContext(
            executableURL: executableURL,
            port: port,
            sessionToken: token,
            tokenFileURL: tokenFileURL
        )
    }

    private func configure(
        _ process: Process,
        outputPipe: Pipe,
        launchContext: CoreProcessLaunchContext,
        onOutput: @escaping @MainActor (String) -> Void,
        onTermination: @escaping @MainActor (Int32) -> Void
    ) {
        process.executableURL = launchContext.executableURL
        process.arguments = launchContext.serveArguments
        process.environment = Self.coreEnvironment()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard self?.process === process else { return }
                self?.flushProcessOutput(onOutput: onOutput)
                self?.lastTerminationStatus = process.terminationStatus
                self?.cleanupRunningProcessState(keepingLastTerminationStatus: true)
                onOutput("Core exited with status \(process.terminationStatus)")
                onTermination(process.terminationStatus)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.consumeProcessOutput(text, onOutput: onOutput)
            }
        }
    }

    private func track(
        _ process: Process,
        outputPipe: Pipe,
        launchContext: CoreProcessLaunchContext,
        startedAt: Date
    ) {
        self.process = process
        self.outputPipe = outputPipe
        self.endpoint = launchContext.endpoint
        self.managedExecutableURL = launchContext.standardizedExecutableURL
        self.managedStartedAt = startedAt
    }

    private func consumeProcessOutput(_ text: String, onOutput: @MainActor (String) -> Void) {
        for line in outputBuffer.append(text) {
            onOutput(line)
        }
    }

    private func flushProcessOutput(onOutput: @MainActor (String) -> Void) {
        if let value = outputBuffer.flush() {
            onOutput(value)
        }
    }

    private func cleanupRunningProcessState(keepingLastTerminationStatus: Bool = false) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        endpoint = nil
        outputBuffer.reset()
        managedExecutableURL = nil
        managedStartedAt = nil
        if !keepingLastTerminationStatus {
            lastTerminationStatus = nil
        }
    }

    private func waitForCore(endpoint: CoreEndpoint) async throws {
        try await CoreProcessReadinessWaiter.wait(endpoint: endpoint) {
            if let lastTerminationStatus {
                return lastTerminationStatus
            }
            if let process, !process.isRunning {
                return process.terminationStatus
            }
            return nil
        }
    }
}
