import AppKit
import Foundation

@MainActor
extension LauncherViewModel {
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
