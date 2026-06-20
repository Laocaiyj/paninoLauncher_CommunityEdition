import Foundation

@MainActor
extension LauncherViewModel {
    func install(
        version requestedVersionOverride: String? = nil,
        gameDir: String? = nil,
        loader: LoaderKind? = nil,
        loaderVersion: String? = nil,
        shaderLoader: String? = nil,
        shaderVersion: String? = nil,
        instanceName: String? = nil,
        restartActiveTask: Bool = false
    ) {
        guard restartActiveTask ? canStartTaskSubmission : canSubmitTask else { return }
        let requestedVersion = sanitizedVersion(requestedVersionOverride)
        guard let isolatedGameDir = sanitizedGameDir(gameDir) else {
            appendLog("Install blocked: missing isolated game directory")
            return
        }
        let downloadOptions = LauncherSettings.storedDownloadRuntimeOptions()
        appendLog("Install requested for \(requestedVersion)\(logGameDirSuffix(gameDir)); concurrency=\(downloadOptions.concurrency); retryCount=\(downloadOptions.retryCount)")

        submissionTask?.cancel()
        submissionTask = Task {
            defer { submissionTask = nil }
            do {
                try await ensureClient()
                guard !Task.isCancelled else { return }
                guard let apiClient else { return }
                if restartActiveTask {
                    try await cancelActiveTaskBeforeRetry(using: apiClient)
                    guard !Task.isCancelled else { return }
                }
                let accepted = try await apiClient.install(
                    version: requestedVersion,
                    gameDir: isolatedGameDir,
                    loader: loader?.rawValue,
                    loaderVersion: loaderVersion,
                    shaderLoader: shaderLoader,
                    shaderVersion: shaderVersion,
                    instanceName: instanceName,
                    downloadOptions: downloadOptions
                )
                currentTask = accepted.task
                appendLog("Task \(accepted.taskId) queued")
                pollTask(id: accepted.taskId)
            } catch {
                appendLog("Install failed: \(error.localizedDescription)")
                let failure = LauncherTaskFailureSnapshots.installFailure(
                    version: requestedVersion,
                    gameDir: isolatedGameDir,
                    loader: loader,
                    shaderLoader: shaderLoader,
                    error: error
                )
                currentTask = failure
                lastTaskFailure = failure
            }
        }
    }

    func installContent(_ request: CoreContentInstallRequest) {
        guard canSubmitTask else { return }
        guard sanitizedGameDir(request.gameDir) != nil else {
            appendLog("Content install blocked: missing isolated game directory")
            return
        }
        let downloadOptions = LauncherSettings.storedDownloadRuntimeOptions()
        let runtimeRequest = request.withEffectiveDownloadOptions(downloadOptions)
        appendLog("Content install requested for \(request.projectTitle); concurrency=\(runtimeRequest.concurrency ?? downloadOptions.concurrency); retryCount=\(runtimeRequest.retryCount ?? downloadOptions.retryCount)")

        submissionTask?.cancel()
        submissionTask = Task {
            defer { submissionTask = nil }
            do {
                try await ensureClient()
                guard !Task.isCancelled else { return }
                guard let apiClient else { return }
                let accepted = try await apiClient.installContent(runtimeRequest)
                currentTask = accepted.task
                appendLog("Task \(accepted.taskId) queued")
                pollTask(id: accepted.taskId)
            } catch {
                appendLog("Content install failed: \(error.localizedDescription)")
            }
        }
    }

    func installPerformancePack(_ request: CorePerformancePackInstallRequest) {
        guard canSubmitTask else { return }
        guard sanitizedGameDir(request.gameDir) != nil else {
            appendLog("Performance pack install blocked: missing isolated game directory")
            return
        }
        appendLog("Performance pack install requested for \(request.minecraftVersion) \(request.loader)")

        submissionTask?.cancel()
        submissionTask = Task {
            defer { submissionTask = nil }
            do {
                try await ensureClient()
                guard !Task.isCancelled else { return }
                guard let apiClient else { return }
                let accepted = try await apiClient.installPerformancePack(request)
                currentTask = accepted.task
                appendLog("Task \(accepted.taskId) queued")
                pollTask(id: accepted.taskId)
            } catch {
                appendLog("Performance pack install failed: \(error.localizedDescription)")
            }
        }
    }

    func installContentAccepted(_ request: CoreContentInstallRequest) async throws -> TaskAccepted {
        guard canSubmitTask else { throw LauncherApiError.invalidResponse }
        guard sanitizedGameDir(request.gameDir) != nil else {
            appendLog("Content install blocked: missing isolated game directory")
            throw LauncherApiError.invalidResponse
        }
        let downloadOptions = LauncherSettings.storedDownloadRuntimeOptions()
        let runtimeRequest = request.withEffectiveDownloadOptions(downloadOptions)
        appendLog("Content install requested for \(request.projectTitle); concurrency=\(runtimeRequest.concurrency ?? downloadOptions.concurrency); retryCount=\(runtimeRequest.retryCount ?? downloadOptions.retryCount)")
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        let accepted = try await apiClient.installContent(runtimeRequest)
        currentTask = accepted.task
        appendLog("Task \(accepted.taskId) queued")
        pollTask(id: accepted.taskId)
        return accepted
    }

    func cancelCurrentTask() {
        submissionTask?.cancel()
        logExportTask?.cancel()
        guard let currentTask, currentTask.state.isActive else {
            appendLog("Cancelled pending launcher task")
            return
        }
        appendLog("Cancelling task \(currentTask.taskId)")

        cancelTask?.cancel()
        cancelTask = Task {
            do {
                guard let apiClient else { return }
                let accepted = try await apiClient.cancelTask(id: currentTask.taskId)
                self.currentTask = accepted.task
                appendLog("Task \(accepted.taskId) cancellation requested")
            } catch {
                appendLog("Cancel failed: \(error.localizedDescription)")
            }
        }
    }

    func pollTask(id taskId: String) {
        taskPoller?.cancel()
        taskPoller = Task {
            while !Task.isCancelled {
                guard let apiClient else { return }
                do {
                    let task = try await apiClient.task(id: taskId)
                    currentTask = task
                    if task.state.isTerminal {
                        appendLog("Task \(task.taskId) \(task.state.rawValue): \(task.message ?? "")")
                        if task.state == .failed {
                            lastTaskFailure = task
                        }
                        handleTerminalTask(task)
                        return
                    }
                } catch {
                    if let missingTask = LauncherTaskFailureSnapshots.missingTaskSnapshot(taskId: taskId, error: error, currentTask: currentTask) {
                        currentTask = missingTask
                        lastTaskFailure = missingTask
                        appendLog("Task \(taskId) disappeared from Core; marked interrupted locally")
                        handleTerminalTask(missingTask)
                        return
                    }
                    appendLog("Task polling failed: \(error.localizedDescription)")
                    return
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    func sanitizedVersion() -> String {
        sanitizedVersion(nil)
    }

    func sanitizedVersion(_ value: String?) -> String {
        let trimmed = (value ?? version).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "1.20.1" : trimmed
    }

    func sanitizedJavaPath() -> String? {
        let trimmed = javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func sanitizedGameDir(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func logGameDirSuffix(_ value: String?) -> String {
        guard let gameDir = sanitizedGameDir(value) else { return "" }
        return " in \(gameDir)"
    }

    func cancelActiveTaskBeforeRetry(using apiClient: LauncherApiClient) async throws {
        guard let activeTask = currentTask, activeTask.state.isActive else { return }
        appendLog("Cancelling task \(activeTask.taskId) before retry")
        let accepted = try await apiClient.cancelTask(id: activeTask.taskId)
        currentTask = accepted.task
        try await waitForTaskToStop(id: activeTask.taskId, using: apiClient)
    }

    private func waitForTaskToStop(id taskId: String, using apiClient: LauncherApiClient) async throws {
        for _ in 0..<30 {
            guard !Task.isCancelled else { return }
            let snapshot = try await apiClient.task(id: taskId)
            currentTask = snapshot
            if snapshot.state.isTerminal {
                appendLog("Task \(taskId) stopped before retry: \(snapshot.state.rawValue)")
                return
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        appendLog("Retry continuing after cancellation wait timed out for task \(taskId)")
    }

    func handleTerminalTask(_ task: TaskSnapshot) {
        if task.kind == "runtime.install", task.state == .succeeded {
            loadManagedJavaRuntimes()
        }
        guard let pending = pendingJavaRuntimeLaunch, pending.taskId == task.taskId else { return }
        pendingJavaRuntimeLaunch = nil
        guard task.state == .succeeded else {
            appendLog("Launch after Java install skipped: \(task.state.rawValue)")
            return
        }
        appendLog("Java runtime installed; continuing launch for \(pending.version)")
        launch(version: pending.version, accountID: pending.accountID, gameDir: pending.gameDir, instance: pending.instance)
    }

}
