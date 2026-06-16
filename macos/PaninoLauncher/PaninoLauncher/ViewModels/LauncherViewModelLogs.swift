import Foundation

@MainActor
extension LauncherViewModel {
    func clearLogs() {
        logs.removeAll()
    }

    func exportLogs() {
        logExportTask?.cancel()
        let logSnapshot = logs
        logExportTask = Task {
            defer { logExportTask = nil }
            do {
                let url = try await writeLogsToDisk(logSnapshot: logSnapshot)
                guard !Task.isCancelled else { return }
                lastExportedLogURL = url
                appendLog("Logs exported to \(url.path)")
            } catch {
                if !Task.isCancelled {
                    appendLog("Log export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func handle(event: CoreEvent) {
        latestCoreEvent = event

        if event.eventType == "task.progress",
           let progress = event.payload?.taskProgress(taskId: event.taskId) {
            currentTaskProgress = progress
        }

        if let taskId = event.taskId, event.isTerminalTaskEvent {
            refreshTerminalTaskSnapshot(taskId: taskId)
        }

        let prefix = event.taskId.map { "[\($0)] " } ?? ""
        let progressText = event.payload?.overallPercent.map { String(format: " %.1f%%", $0) }
            ?? event.payload?.percent.map { String(format: " %.1f%%", $0) }
            ?? ""
        let label = event.payload?.currentLabel.map { " \($0)" }
            ?? event.payload?.label.map { " \($0)" }
            ?? ""
        let phase = event.payload?.phaseTitle.map { " \($0)" } ?? ""
        let summary = "\(prefix)\(event.eventType): \(event.message)\(progressText)\(phase)\(label)"
        let detail = (event.payload?.diagnostic?.developerDetail ?? event.payload?.errorDetail)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = [summary, detail].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: "\n")

        if event.eventType == "task.failed" {
            appendLog(text, source: .core)
        } else {
            appendThrottledLog(text, source: .core)
        }
    }

    func refreshTerminalTaskSnapshot(taskId: String) {
        Task {
            do {
                guard let apiClient else { return }
                let task = try await apiClient.task(id: taskId)
                currentTask = task
                if currentTaskProgress?.taskId == taskId {
                    currentTaskProgress = task.progress
                }
                if task.state == .failed {
                    lastTaskFailure = task
                }
                handleTerminalTask(task)
            } catch {
                appendLog("Task terminal refresh failed for \(taskId): \(error.localizedDescription)")
            }
        }
    }

    func writeLogsToDisk(logSnapshot: [LogLine]) async throws -> URL {
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let logDirectory = try fileManager
                .url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent("Panino Launcher", isDirectory: true)
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"

            let url = logDirectory.appendingPathComponent("panino-launcher-\(formatter.string(from: Date())).log")
            let content = logSnapshot.map(\.text).joined(separator: "\n") + "\n"
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        }.value
    }

    func appendThrottledLog(_ text: String, source: LogSource) {
        let now = Date()
        if now.timeIntervalSince(lastEventLogAt) >= 0.25 {
            lastEventLogAt = now
            appendLog(text, source: source)
            return
        }

        pendingEventLog = (text, source)
        guard eventLogFlushTask == nil else { return }

        eventLogFlushTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            if let pendingEventLog {
                self.pendingEventLog = nil
                lastEventLogAt = Date()
                appendLog(pendingEventLog.text, source: pendingEventLog.source)
            }
            eventLogFlushTask = nil
        }
    }

    func appendLog(_ text: String, source: LogSource = .app) {
        let redactedText = LogRedactor.redact(text)
        let lines = redactedText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }

        if lines.isEmpty {
            logs.append(LogLine(text: redactedText, source: source))
        } else {
            logs.append(contentsOf: lines.map { LogLine(text: $0, source: source) })
        }

        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }
}

private extension CoreEvent {
    var isTerminalTaskEvent: Bool {
        switch eventType {
        case "task.succeeded", "task.failed", "task.cancelled":
            return true
        default:
            return payload?.state == "succeeded"
                || payload?.state == "failed"
                || payload?.state == "cancelled"
        }
    }
}
