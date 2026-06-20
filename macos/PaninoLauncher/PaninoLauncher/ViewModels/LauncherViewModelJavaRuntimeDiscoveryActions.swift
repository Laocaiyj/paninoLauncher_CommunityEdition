import Foundation

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
}
