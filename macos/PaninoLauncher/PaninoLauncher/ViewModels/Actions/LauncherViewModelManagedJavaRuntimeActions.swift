import Foundation

@MainActor
extension LauncherViewModel {
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
}
