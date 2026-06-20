import Foundation
import AppKit

@MainActor
extension LauncherViewModel {
    func checkJavaRuntime() {
        javaCheckTask?.cancel()
        javaStatus = JavaRuntimeStatus(
            path: sanitizedJavaPath() ?? "java",
            isAvailable: false,
            versionSummary: "Checking Java runtime..."
        )

        javaCheckTask = Task {
            do {
                try await ensureClient()
                guard !Task.isCancelled else { return }
                guard let apiClient else { return }
                let status = try await apiClient.checkJavaRuntime(
                    CoreJavaCheckRequest(java: sanitizedJavaPath())
                )
                guard !Task.isCancelled else { return }
                javaStatus = status
                appendLog("Java check via Core: \(status.displayText)")
            } catch {
                guard !Task.isCancelled else { return }
                let status = JavaRuntimeStatus(
                    path: sanitizedJavaPath() ?? "java",
                    isAvailable: false,
                    versionSummary: "Java check failed: \(error.localizedDescription)"
                )
                javaStatus = status
                appendLog("Java check failed: \(error.localizedDescription)")
            }
        }
    }

    func scanJavaRuntimes() {
        javaScanTask?.cancel()
        javaScanStatus = "Scanning Java runtimes via Core..."

        javaScanTask = Task {
            do {
                try await ensureClient()
                guard !Task.isCancelled else { return }
                guard let apiClient else { return }
                let runtimes = try await apiClient.scanJavaRuntimes()
                guard !Task.isCancelled else { return }
                discoveredJavaRuntimes = runtimes
                javaScanStatus = "Found \(runtimes.filter(\.isAvailable).count) available Java runtimes"
                appendLog("Java scan via Core: \(runtimes.count) candidates")
            } catch {
                guard !Task.isCancelled else { return }
                discoveredJavaRuntimes = []
                javaScanStatus = "Java scan failed: \(error.localizedDescription)"
                appendLog("Java scan failed: \(error.localizedDescription)")
            }
        }
    }

    func loadManagedJavaRuntimes() {
        javaRuntimeTask?.cancel()
        javaRuntimeStatus = "Loading managed Java runtimes..."

        javaRuntimeTask = Task {
            do {
                try await ensureClient()
                guard !Task.isCancelled else { return }
                guard let apiClient else { return }
                let response = try await apiClient.managedJavaRuntimes()
                guard !Task.isCancelled else { return }
                managedJavaRuntimes = response.runtimes
                managedJavaRoot = response.root
                javaRuntimeStatus = response.runtimes.isEmpty
                    ? "No managed Java runtimes installed"
                    : "Managed Java runtimes: \(response.runtimes.count)"
            } catch {
                guard !Task.isCancelled else { return }
                javaRuntimeStatus = "Managed Java load failed: \(error.localizedDescription)"
                appendLog("Managed Java load failed: \(error.localizedDescription)")
            }
        }
    }

    func resolveJavaRuntime(
        version requestedVersionOverride: String? = nil,
        gameDir: String? = nil,
        instanceId: String? = nil,
        customPath: String? = nil
    ) {
        let requestedVersion = sanitizedVersion(requestedVersionOverride)
        javaRuntimeStatus = "Resolving Java for \(requestedVersion)..."

        Task {
            do {
                try await ensureClient()
                guard let apiClient else { return }
                let request = CoreJavaRuntimeResolveRequest(
                    minecraftVersion: requestedVersion,
                    gameDir: sanitizedGameDir(gameDir),
                    instanceId: instanceId,
                    policy: customPath == nil ? nil : "custom",
                    preferredRuntimeId: nil,
                    customPath: customPath
                )
                let resolution = try await apiClient.resolveJavaRuntime(request)
                javaRuntimeResolution = resolution
                javaRuntimeStatus = resolution.conciseStatus
            } catch {
                javaRuntimeResolution = nil
                javaRuntimeStatus = "Java resolve failed: \(error.localizedDescription)"
                appendLog("Java resolve failed: \(error.localizedDescription)")
            }
        }
    }

    func installManagedJavaRuntime(
        featureVersion: Int,
        setDefault: Bool = false,
        launchAfterInstall: PendingJavaRuntimeLaunch? = nil
    ) {
        guard canStartTaskSubmission else { return }
        let downloadOptions = LauncherSettings.storedDownloadRuntimeOptions()
        appendLog("Java \(featureVersion) runtime install requested")

        submissionTask?.cancel()
        submissionTask = Task {
            defer { submissionTask = nil }
            do {
                try await ensureClient()
                guard !Task.isCancelled else { return }
                guard let apiClient else { return }
                let accepted = try await apiClient.installJavaRuntime(
                    CoreJavaRuntimeInstallRequest(
                        featureVersion: featureVersion,
                        provider: "adoptium",
                        vendor: "temurin",
                        os: nil,
                        arch: nil,
                        imageType: "jre",
                        setDefault: setDefault,
                        download: downloadOptions
                    )
                )
                if var pending = launchAfterInstall {
                    pending = PendingJavaRuntimeLaunch(
                        taskId: accepted.taskId,
                        version: pending.version,
                        accountID: pending.accountID,
                        gameDir: pending.gameDir,
                        instance: pending.instance
                    )
                    pendingJavaRuntimeLaunch = pending
                }
                currentTask = accepted.task
                javaRuntimeStatus = "Downloading Java \(featureVersion)"
                appendLog("Java runtime task \(accepted.taskId) queued")
                pollTask(id: accepted.taskId)
            } catch {
                appendLog("Java runtime install failed: \(error.localizedDescription)")
                javaRuntimeStatus = "Java install failed: \(error.localizedDescription)"
            }
        }
    }

    func selectManagedJavaRuntime(_ runtime: CoreJavaManagedRuntime) {
        javaRuntimeStatus = "Saving Java \(runtime.featureVersion) as default..."
        Task {
            do {
                try await ensureClient()
                guard let apiClient else { return }
                let response = try await apiClient.selectJavaRuntime(
                    CoreJavaRuntimeSelectRequest(
                        scope: "global",
                        instanceId: nil,
                        policy: "managed",
                        preferredRuntimeId: runtime.id,
                        customPath: nil,
                        lockPatchVersion: false
                    )
                )
                javaPath = ""
                javaRuntimeStatus = response.message
                resolveJavaRuntime(version: version)
            } catch {
                javaRuntimeStatus = "Java policy save failed: \(error.localizedDescription)"
                appendLog("Java policy save failed: \(error.localizedDescription)")
            }
        }
    }

    func cleanupManagedJavaRuntimes() {
        javaRuntimeStatus = "Cleaning managed Java runtimes..."
        Task {
            do {
                try await ensureClient()
                guard let apiClient else { return }
                let response = try await apiClient.cleanupJavaRuntimes()
                javaRuntimeStatus = response.message
                loadManagedJavaRuntimes()
            } catch {
                javaRuntimeStatus = "Java cleanup failed: \(error.localizedDescription)"
                appendLog("Java cleanup failed: \(error.localizedDescription)")
            }
        }
    }

    func importManagedJavaRuntime() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Import Java Runtime"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        javaRuntimeStatus = "Importing Java runtime..."
        Task {
            do {
                try await ensureClient()
                guard let apiClient else { return }
                let runtime = try await apiClient.importJavaRuntime(
                    CoreJavaRuntimeImportRequest(
                        sourcePath: url.path,
                        provider: "local",
                        vendor: "local",
                        featureVersion: nil,
                        os: nil,
                        arch: nil,
                        imageType: "jre",
                        setDefault: false
                    )
                )
                javaRuntimeStatus = "Imported \(runtime.displayName)"
                loadManagedJavaRuntimes()
            } catch {
                javaRuntimeStatus = "Java import failed: \(error.localizedDescription)"
                appendLog("Java import failed: \(error.localizedDescription)")
            }
        }
    }

    func verifyManagedJavaRuntime(_ runtime: CoreJavaManagedRuntime) {
        javaRuntimeStatus = "Verifying \(runtime.displayName)..."
        Task {
            do {
                try await ensureClient()
                guard let apiClient else { return }
                _ = try await apiClient.verifyJavaRuntime(id: runtime.id)
                javaRuntimeStatus = "\(runtime.displayName) verified"
                loadManagedJavaRuntimes()
            } catch {
                javaRuntimeStatus = "Java verify failed: \(error.localizedDescription)"
                appendLog("Java verify failed: \(error.localizedDescription)")
            }
        }
    }

    func deleteManagedJavaRuntime(_ runtime: CoreJavaManagedRuntime) {
        javaRuntimeStatus = "Removing \(runtime.displayName)..."
        Task {
            do {
                try await ensureClient()
                guard let apiClient else { return }
                let response = try await apiClient.deleteJavaRuntime(id: runtime.id)
                javaRuntimeStatus = response.message
                loadManagedJavaRuntimes()
            } catch {
                javaRuntimeStatus = "Java remove failed: \(error.localizedDescription)"
                appendLog("Java remove failed: \(error.localizedDescription)")
            }
        }
    }

    func deleteLocalJavaRuntime(_ runtime: JavaRuntimeCandidate) {
        javaScanStatus = "Removing local Java runtime..."
        Task {
            do {
                try await ensureClient()
                guard let apiClient else { return }
                let response = try await apiClient.deleteLocalJavaRuntime(path: runtime.path)
                javaScanStatus = response.message
                scanJavaRuntimes()
            } catch {
                javaScanStatus = "Local Java remove failed: \(error.localizedDescription)"
                appendLog("Local Java remove failed: \(error.localizedDescription)")
            }
        }
    }
}
