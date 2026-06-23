import Foundation

@MainActor
extension LauncherViewModel {
    func startCoreIfNeeded() async {
        if coreState.isReady {
            return
        }

        if let coreStartTask {
            await coreStartTask.value
            return
        }

        let task = Task { @MainActor in
            await self.startCoreProcess()
        }
        coreStartTask = task
        await task.value
        coreStartTask = nil
    }

    func startCoreProcess() async {
        guard !coreState.isReady, coreState != .starting else { return }
        coreState = .starting
        expectedCoreStop = false
        appendLog("Starting local Core service")

        do {
            let endpoint = try await processManager.start(
                onOutput: { [weak self] output in
                    self?.appendLog(output, source: .core)
                },
                onTermination: { [weak self] status in
                    self?.handleCoreTermination(status: status)
                }
            )
            let client = LauncherApiClient(endpoint: endpoint)
            apiClient = client
            coreState = .running
            coreRestartAttempts = 0
            appendLog("Core connected at \(endpoint.baseURL.absoluteString)")
            startEventStream(client: client)
        } catch {
            coreState = .failed(error.localizedDescription)
            appendLog("Core startup failed: \(error.localizedDescription)")
        }
    }

    func shutdownCore() async {
        eventTask?.cancel()
        taskPoller?.cancel()
        authTask?.cancel()
        javaCheckTask?.cancel()
        javaScanTask?.cancel()
        coreStartTask?.cancel()
        submissionTask?.cancel()
        cancelTask?.cancel()
        logExportTask?.cancel()
        eventLogFlushTask?.cancel()
        expectedCoreStop = true
        coreState = .stopping
        appendLog("Stopping Core service")
        await processManager.stop(using: apiClient)
        apiClient = nil
        currentTask = nil
        coreState = .stopped
        appendLog("Core stopped")
    }

    func ensureClient() async throws {
        if let client = apiClient, coreState.isReady, processManager.shouldRestartForUpdatedExecutable() {
            appendLog("Core executable changed; restarting local Core service")
            eventTask?.cancel()
            expectedCoreStop = true
            coreState = .stopping
            await processManager.stop(using: client)
            apiClient = nil
            expectedCoreStop = false
            coreState = .stopped
        }
        if apiClient == nil || !coreState.isReady {
            await startCoreIfNeeded()
        }
    }

    func startEventStream(client: LauncherApiClient) {
        eventTask?.cancel()
        let streamClient = EventStreamClient(apiClient: client)
        eventTask = Task {
            do {
                for try await event in streamClient.events() {
                    handle(event: event)
                }
            } catch {
                appendLog("Event stream ended: \(error.localizedDescription)")
            }
        }
    }

    func handleCoreTermination(status: Int32) {
        eventTask?.cancel()
        taskPoller?.cancel()
        apiClient = nil

        if expectedCoreStop {
            expectedCoreStop = false
            return
        }

        let message = "Core exited unexpectedly with status \(status)."
        if coreRestartAttempts < 1 {
            coreRestartAttempts += 1
            coreState = .stopped
            appendLog("\(message) Restarting Core once.")
            Task {
                await startCoreIfNeeded()
            }
            return
        }

        coreState = .failed("\(message) Start Core again to recover.")
        appendLog("\(message) Restart was already attempted.")
    }
}
