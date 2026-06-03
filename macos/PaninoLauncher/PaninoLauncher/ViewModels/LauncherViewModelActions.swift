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
                let failure = syntheticInstallFailure(
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

    func launch(
        version requestedVersionOverride: String? = nil,
        accountID: String? = nil,
        gameDir: String? = nil,
        instance: GameInstance? = nil,
        restartActiveTask: Bool = false
    ) {
        guard restartActiveTask ? canStartTaskSubmission : canLaunch(gameDir: gameDir) else { return }
        let requestedVersion = sanitizedVersion(requestedVersionOverride ?? instance?.minecraftVersion)
        guard let isolatedGameDir = sanitizedGameDir(gameDir) else {
            appendLog("Launch blocked: missing isolated game directory")
            return
        }
        let installBeforeLaunch = LauncherSettings.storedInstallMissingFilesBeforeLaunch()
        let downloadOptions = LauncherSettings.storedDownloadRuntimeOptions()
        let windowSize = LauncherSettings.storedWindowSize()
        appendLog("Launch requested for \(requestedVersion)\(logGameDirSuffix(gameDir)); installBeforeLaunch=\(installBeforeLaunch); concurrency=\(downloadOptions.concurrency); retryCount=\(downloadOptions.retryCount)")

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
                await applyLaunchGraphicsTuningIfNeeded(
                    apiClient: apiClient,
                    requestedVersion: requestedVersion,
                    gameDir: isolatedGameDir,
                    instance: instance
                )
                guard !Task.isCancelled else { return }
                let javaResolveVersion = instance?.contentMinecraftVersion ?? requestedVersion
                let requestedJavaPath = sanitizedJavaPath()
                let javaPath: String?
                if let requestedJavaPath {
                    javaPath = requestedJavaPath
                } else {
                    let resolution = try await apiClient.resolveJavaRuntime(
                        CoreJavaRuntimeResolveRequest(
                            minecraftVersion: javaResolveVersion,
                            gameDir: isolatedGameDir,
                            instanceId: nil,
                            policy: nil,
                            preferredRuntimeId: nil,
                            customPath: nil
                        )
                    )
                    javaRuntimeResolution = resolution
                    javaRuntimeStatus = resolution.conciseStatus
                    if resolution.isDownloadable {
                        let accepted = try await apiClient.installJavaRuntime(
                            CoreJavaRuntimeInstallRequest(
                                featureVersion: resolution.requiredMajorVersion,
                                provider: resolution.download?.provider ?? "adoptium",
                                vendor: resolution.download?.vendor ?? "temurin",
                                os: resolution.download?.os,
                                arch: resolution.download?.arch,
                                imageType: resolution.download?.imageType ?? "jre",
                                setDefault: false,
                                download: downloadOptions
                            )
                        )
                        pendingJavaRuntimeLaunch = PendingJavaRuntimeLaunch(
                            taskId: accepted.taskId,
                            version: requestedVersion,
                            accountID: accountID,
                            gameDir: isolatedGameDir,
                            instance: instance
                        )
                        currentTask = accepted.task
                        appendLog("Java runtime task \(accepted.taskId) queued before launch")
                        pollTask(id: accepted.taskId)
                        return
                    }
                    guard resolution.isReady, let resolvedJavaPath = resolution.javaExecutable else {
                        appendLog("Launch blocked: \(resolution.conciseStatus)")
                        return
                    }
                    javaPath = resolvedJavaPath
                }
                let account = try await launchAccount(accountID: accountID)
                guard !Task.isCancelled else { return }
                let customJvmArguments = instance.map { splitJvmArguments($0.customJvmArguments) } ?? LauncherSettings.storedJVMArguments()
                let configuredMemoryMb = instance.map { target in
                    target.memoryPolicy == .custom ? (target.customMemoryMb ?? target.memoryMb) : target.memoryMb
                } ?? memoryMb
                let accepted = try await apiClient.launch(
                    version: requestedVersion,
                    memoryMb: configuredMemoryMb,
                    javaPath: javaPath,
                    account: account,
                    gameDir: isolatedGameDir,
                    instanceId: instance?.id.uuidString,
                    loader: instance?.loader?.rawValue,
                    memoryPolicy: instance?.memoryPolicy.rawValue,
                    jvmProfile: instance?.jvmProfile.rawValue,
                    customMemoryMb: instance?.customMemoryMb,
                    customJvmArguments: customJvmArguments,
                    installBeforeLaunch: installBeforeLaunch,
                    downloadOptions: downloadOptions,
                    jvmArguments: customJvmArguments,
                    windowWidth: windowSize.width,
                    windowHeight: windowSize.height
                )
                currentTask = accepted.task
                appendLog("Task \(accepted.taskId) queued")
                pollTask(id: accepted.taskId)
            } catch {
                appendLog("Launch failed: \(error.localizedDescription)")
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
                    if let missingTask = missingTaskSnapshot(taskId: taskId, error: error) {
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

    private func logGameDirSuffix(_ value: String?) -> String {
        guard let gameDir = sanitizedGameDir(value) else { return "" }
        return " in \(gameDir)"
    }

    private func cancelActiveTaskBeforeRetry(using apiClient: LauncherApiClient) async throws {
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

    private func syntheticInstallFailure(version: String, gameDir: String?, loader: LoaderKind?, shaderLoader: String?, error: Error) -> TaskSnapshot {
        let rawDetail = error.localizedDescription
        let blocked = installPreflightBlockedError(from: error)
        let blockedReason = blocked?.blockedReasons?.first ?? blocked?.preflight?.blockedReasons.first
        let message = blockedReason ?? rawDetail
        let detail = [
            "requestedMinecraftVersion=\(version)",
            "requestedGameDir=\(gameDir ?? "-")",
            "requestedLoader=\(loader?.rawValue ?? "-")",
            "requestedShaderLoader=\(shaderLoader ?? "-")",
            "loaderVersion=\(blocked?.preflight?.loaderVersion ?? "-")",
            "loaderProfileId=\(blocked?.preflight?.loaderProfileId ?? "-")",
            "shaderProjects=\(blocked?.preflight?.shaderProjects.joined(separator: ",") ?? "-")",
            "blockedReasons=\((blocked?.blockedReasons ?? blocked?.preflight?.blockedReasons ?? []).joined(separator: ","))",
            "rawError=\(rawDetail)"
        ].joined(separator: "\n")
        return TaskSnapshot.failedInstall(
            version: version,
            gameDir: gameDir,
            requestedLoader: loader?.rawValue,
            requestedShaderLoader: shaderLoader,
            message: blocked?.diagnostic?.userSummary ?? message,
            errorCode: blocked?.diagnostic?.code ?? blockedReason.flatMap(Self.errorCodePrefix) ?? blocked?.error ?? "install_failed",
            errorDetail: blocked?.diagnostic?.developerDetail ?? detail,
            diagnostic: blocked?.diagnostic,
            diagnostics: blocked?.structuredDiagnostics ?? blocked?.diagnostic.map { [$0] } ?? []
        )
    }

    private func installPreflightBlockedError(from error: Error) -> CoreInstallPreflightBlockedError? {
        guard case let LauncherApiError.unexpectedStatus(_, body) = error else { return nil }
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONDecoder.panino.decode(CoreInstallPreflightBlockedError.self, from: data)
    }

    private func missingTaskSnapshot(taskId: String, error: Error) -> TaskSnapshot? {
        guard case LauncherApiError.unexpectedStatus(404, _) = error else { return nil }
        guard let task = currentTask, task.taskId == taskId else { return nil }
        let detail = [
            "taskId=\(taskId)",
            "lastKnownState=\(task.state.rawValue)",
            "rawError=\(error.localizedDescription)"
        ].joined(separator: "\n")
        return TaskSnapshot(
            taskId: task.taskId,
            kind: task.kind,
            version: task.version,
            gameDir: task.gameDir,
            requestedLoader: task.requestedLoader,
            requestedShaderLoader: task.requestedShaderLoader,
            state: .failed,
            message: "Task was interrupted before Core reported a final state.",
            errorCode: "task_not_found",
            errorDetail: detail,
            diagnostic: task.diagnostic,
            diagnostics: task.diagnostics,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            finishedAt: task.updatedAt,
            progress: task.progress
        )
    }

    private static func errorCodePrefix(_ value: String) -> String? {
        let prefix = value.split(separator: ":", maxSplits: 1).first.map(String.init)
        return prefix?.isEmpty == false ? prefix : nil
    }

    private func applyLaunchGraphicsTuningIfNeeded(
        apiClient: LauncherApiClient,
        requestedVersion: String,
        gameDir: String,
        instance: GameInstance?
    ) async {
        guard LauncherSettings.storedPerformanceLocalTelemetryEnabled() else {
            appendLog("Graphics tuning before launch skipped: local performance telemetry is disabled.")
            return
        }
        guard LauncherSettings.storedPerformanceExperimentsEnabled() else {
            appendLog("Graphics tuning before launch skipped: adaptive performance experiments are disabled.")
            return
        }
        switch LauncherSettings.storedPerformanceApplyMode() {
        case .automatic:
            break
        case .ask:
            appendLog("Graphics tuning before launch needs review: automatic apply mode is Ask First.")
            return
        case .never:
            appendLog("Graphics tuning before launch skipped: automatic apply is disabled.")
            return
        }

        let request = CoreGraphicsTuningRequest(
            instanceId: instance?.id.uuidString,
            gameDir: gameDir,
            minecraftVersion: instance?.contentMinecraftVersion ?? requestedVersion,
            loader: instance?.loader?.rawValue,
            requestedProfile: (instance?.graphicsProfile ?? LauncherSettings.storedGraphicsProfile()).rawValue,
            manualOverrides: instance?.graphicsManualOverrides ?? [:],
            dryRun: false
        )

        do {
            let resolved = try await apiClient.resolveGraphicsTuning(request)
            guard resolved.canApply else { return }
            let response = try await apiClient.applyGraphicsTuning(request)
            appendLog("Graphics tuning applied before launch: \(response.tuning.summary)")
        } catch {
            appendLog("Graphics tuning before launch skipped: \(error.localizedDescription)")
        }
    }
}
