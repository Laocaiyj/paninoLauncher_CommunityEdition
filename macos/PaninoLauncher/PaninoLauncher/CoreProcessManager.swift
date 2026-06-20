import Darwin
import Foundation

enum CoreProcessManagerError: LocalizedError, Equatable {
    case coreExecutableNotFound([String])
    case coreExitedEarly(Int32)
    case healthTimedOut
    case socketFailed(String)
    case tokenFileFailed(String)

    var errorDescription: String? {
        switch self {
        case .coreExecutableNotFound(let searchedPaths):
            return "Core executable was not found. Searched: \(searchedPaths.joined(separator: ", "))"
        case .coreExitedEarly(let status):
            return "Core exited before becoming ready with status \(status)."
        case .healthTimedOut:
            return "Core did not become ready before the health check timeout."
        case .socketFailed(let message):
            return "Failed to allocate a local port: \(message)"
        case .tokenFileFailed(let message):
            return "Failed to prepare Core session token: \(message)"
        }
    }
}

@MainActor
final class CoreProcessManager {
    private var process: Process?
    private var outputPipe: Pipe?
    private var endpoint: CoreEndpoint?
    private var outputBuffer = ""
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
                await stopRunningProcess(process, apiClient: LauncherApiClient(endpoint: endpoint))
                cleanupRunningProcessState()
                Self.removeManagedCoreRecord()
            } else {
                return endpoint
            }
        }

        Self.emergencyStopRecordedCore()

        let executableURL = try findCoreExecutable()
        let port = try allocateLoopbackPort()
        let token = makeSessionToken()
        lastTerminationStatus = nil
        let endpoint = CoreEndpoint(
            baseURL: URL(string: "http://127.0.0.1:\(port)")!,
            sessionToken: token
        )

        let process = Process()
        let outputPipe = Pipe()
        let tokenFileURL = try Self.createSessionTokenFile(token: token)

        process.executableURL = executableURL
        process.arguments = Self.coreServeArguments(port: port, sessionTokenFileURL: tokenFileURL)
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

        do {
            try process.run()
        } catch {
            Self.removeSessionTokenFile(tokenFileURL)
            throw error
        }
        let startedAt = Date()
        do {
            try Self.recordManagedCoreProcess(
                ManagedCoreRecord(
                    schemaVersion: 2,
                    pid: process.processIdentifier,
                    port: port,
                    executablePath: executableURL.standardizedFileURL.path,
                    startedAt: startedAt
                )
            )
        } catch {
            Self.removeSessionTokenFile(tokenFileURL)
            await stopRunningProcess(process, apiClient: nil)
            throw error
        }

        self.process = process
        self.outputPipe = outputPipe
        self.endpoint = endpoint
        self.managedExecutableURL = executableURL.standardizedFileURL
        self.managedStartedAt = startedAt

        do {
            try await waitForCore(endpoint: endpoint)
            Self.removeSessionTokenFile(tokenFileURL)
            return endpoint
        } catch {
            Self.removeSessionTokenFile(tokenFileURL)
            await stopRunningProcess(process, apiClient: nil)
            Self.removeManagedCoreRecord()
            throw error
        }
    }

    func stop(using apiClient: LauncherApiClient?) async {
        guard let process else {
            Self.emergencyStopRecordedCore()
            return
        }
        await stopRunningProcess(process, apiClient: apiClient)

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

    private func consumeProcessOutput(_ text: String, onOutput: @MainActor (String) -> Void) {
        outputBuffer += text
        let parts = outputBuffer.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        guard !parts.isEmpty else { return }

        let endedWithNewline = outputBuffer.last?.isNewline == true
        let completeLines = endedWithNewline ? parts : parts.dropLast()

        for line in completeLines {
            let value = String(line)
            if !value.isEmpty {
                onOutput(value)
            }
        }

        outputBuffer = endedWithNewline ? "" : String(parts.last ?? "")
    }

    private func flushProcessOutput(onOutput: @MainActor (String) -> Void) {
        let value = outputBuffer.trimmingCharacters(in: .newlines)
        outputBuffer = ""
        if !value.isEmpty {
            onOutput(value)
        }
    }

    private func cleanupRunningProcessState(keepingLastTerminationStatus: Bool = false) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        endpoint = nil
        outputBuffer = ""
        managedExecutableURL = nil
        managedStartedAt = nil
        if !keepingLastTerminationStatus {
            lastTerminationStatus = nil
        }
    }

    private func waitForCore(endpoint: CoreEndpoint) async throws {
        let apiClient = LauncherApiClient(endpoint: endpoint)

        for _ in 0..<60 {
            if let lastTerminationStatus {
                throw CoreProcessManagerError.coreExitedEarly(lastTerminationStatus)
            }

            if let process, !process.isRunning {
                throw CoreProcessManagerError.coreExitedEarly(process.terminationStatus)
            }

            do {
                let response = try await apiClient.health()
                if response.status == "ok" {
                    return
                }
            } catch {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        throw CoreProcessManagerError.healthTimedOut
    }

    private func stopRunningProcess(_ process: Process, apiClient: LauncherApiClient?) async {
        if process.isRunning, let apiClient {
            try? await apiClient.shutdown()
            if await waitForExit(process, timeoutNanoseconds: 1_500_000_000) {
                return
            }
        }

        if process.isRunning {
            process.terminate()
            if await waitForExit(process, timeoutNanoseconds: 1_000_000_000) {
                return
            }
        }

        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            _ = await waitForExit(process, timeoutNanoseconds: 800_000_000)
        }
    }

    private func waitForExit(_ process: Process, timeoutNanoseconds: UInt64) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while process.isRunning && DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return !process.isRunning
    }
}
