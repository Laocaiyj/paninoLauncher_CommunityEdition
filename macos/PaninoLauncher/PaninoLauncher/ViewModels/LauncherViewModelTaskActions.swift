import Foundation

@MainActor
extension LauncherViewModel {
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

    func cancelActiveTaskBeforeRetry(using apiClient: LauncherApiClient) async throws {
        guard let activeTask = currentTask, activeTask.state.isActive else { return }
        appendLog("Cancelling task \(activeTask.taskId) before retry")
        let accepted = try await apiClient.cancelTask(id: activeTask.taskId)
        currentTask = accepted.task
        try await waitForTaskToStop(id: activeTask.taskId, using: apiClient)
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
}
