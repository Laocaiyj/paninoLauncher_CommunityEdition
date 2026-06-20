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
}
