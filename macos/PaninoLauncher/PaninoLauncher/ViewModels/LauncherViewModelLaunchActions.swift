import Foundation

@MainActor
extension LauncherViewModel {
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
