import Foundation

@MainActor
enum DiagnosticsPackageWriter {
    static func redactedLogText(_ logs: [LogLine]) -> String {
        logs.map { LogRedactor.redact($0.text) }.joined(separator: "\n")
    }

    static func installPlanGraphCandidate(tasks: [TaskRecord], fileManager: FileManager) -> URL? {
        diagnosticCandidate(fileName: "install-plan-graph.json", tasks: tasks, fileManager: fileManager)
    }

    static func installPlanDiagnosticArtifacts(tasks: [TaskRecord], fileManager: FileManager) -> [(source: URL, fileName: String)] {
        [
            ("downloads/install-preflight.json", "install-preflight.json"),
            ("downloads/install-state.json", "install-state.json"),
            ("downloads/install-rollback.json", "install-rollback.json"),
            ("downloads/loader-install.log", "loader-install.log"),
            ("downloads/shader-install.log", "shader-install.log"),
            ("downloads/install-plan-execution.json", "install-plan-execution.json"),
            ("downloads/content-install-lock.json", "content-install-lock.json"),
            ("downloads/content-update-lock.json", "content-update-lock.json"),
            ("downloads/performance-pack-lock.json", "performance-pack-lock.json"),
            ("modpack-install-lock.json", "modpack-install-lock.json")
        ]
        .compactMap { relativePath, fileName in
            diagnosticCandidate(relativePath: relativePath, tasks: tasks, fileManager: fileManager)
                .map { ($0, fileName) }
        }
    }

    static func diagnosticCandidate(fileName: String, tasks: [TaskRecord], fileManager: FileManager) -> URL? {
        diagnosticCandidate(relativePath: "downloads/\(fileName)", tasks: tasks, fileManager: fileManager)
    }

    static func diagnosticCandidate(relativePath: String, tasks: [TaskRecord], fileManager: FileManager) -> URL? {
        let taskDirs = tasks
            .compactMap(\.gameDir)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let candidates = Array(NSOrderedSet(array: taskDirs + [LauncherSettings.defaultMinecraftDirectory])) as? [String] ?? []
        return candidates
            .map { diagnosticURL(basePath: $0, relativePath: relativePath) }
            .first { fileManager.fileExists(atPath: $0.path) }
    }

    static func diagnosticDetailValue(_ key: String, in detail: String?) -> String? {
        guard let detail else { return nil }
        let prefix = "\(key)="
        return detail
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty || trimmed == "-" ? nil : trimmed
            }
    }

    static func graphicsOptionsPatchText(_ tuning: CoreResolvedGraphicsTuning) -> String {
        var lines = [
            "Graphics tuning patch",
            "backup: \(tuning.backupPath ?? "-")",
            "summary: \(tuning.summary)",
            ""
        ]
        lines.append(contentsOf: tuning.optionsPatch.changes.map { change in
            [
                change.status,
                change.key,
                "old=\(change.oldValue ?? "-")",
                "new=\(change.newValue ?? "-")",
                "reason=\(change.reason)"
            ].joined(separator: " | ")
        })
        return lines.joined(separator: "\n")
    }

    static func copyPerformanceEvidence(tasks: [TaskRecord], fileManager: FileManager, destination: URL, warnings: inout [String]) throws {
        let taskDirs = tasks
            .compactMap(\.gameDir)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let gameDirs = Array(NSOrderedSet(array: taskDirs + [LauncherSettings.defaultMinecraftDirectory])) as? [String] ?? []
        var copied = false
        for gameDir in gameDirs {
            let root = URL(fileURLWithPath: gameDir, isDirectory: true)
                .appendingPathComponent(".panino", isDirectory: true)
                .appendingPathComponent("performance", isDirectory: true)
            guard fileManager.fileExists(atPath: root.path) else { continue }
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for relativePath in [
                "profiles/applied.json",
                "profiles/user-override.json",
                "experiments/cooldowns"
            ] {
                let source = diagnosticURL(basePath: root.path, relativePath: relativePath)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                let target = destination.appendingPathComponent(relativePath.replacingOccurrences(of: "/", with: "-"))
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory)
                if isDirectory.boolValue {
                    try copyDirectoryContents(fileManager: fileManager, source: source, destination: target, warnings: &warnings)
                } else {
                    try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: source, destination: target, warnings: &warnings)
                }
                copied = true
            }
            let profilesRoot = root.appendingPathComponent("profiles", isDirectory: true)
            if fileManager.fileExists(atPath: profilesRoot.path) {
                try copyDirectoryContents(
                    fileManager: fileManager,
                    source: profilesRoot,
                    destination: destination.appendingPathComponent("profiles", isDirectory: true),
                    warnings: &warnings
                )
                copied = true
            }
            if let profileFiles = try? fileManager.contentsOfDirectory(at: profilesRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for profileFile in profileFiles where profileFile.lastPathComponent.hasPrefix("candidate-") {
                    let target = destination.appendingPathComponent("profiles-\(profileFile.lastPathComponent)")
                    try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: profileFile, destination: target, warnings: &warnings)
                    copied = true
                }
            }
            let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
            if fileManager.fileExists(atPath: sessionsRoot.path) {
                try copyDirectoryContents(
                    fileManager: fileManager,
                    source: sessionsRoot,
                    destination: destination.appendingPathComponent("sessions", isDirectory: true),
                    warnings: &warnings
                )
                copied = true
            }
            if let sessionDirs = try? fileManager.contentsOfDirectory(at: sessionsRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for sessionDir in sessionDirs.sorted(by: { lhs, rhs in
                    let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return left > right
                }).prefix(3) {
                    for fileName in ["performance-session.json", "gc.log"] {
                        let source = sessionDir.appendingPathComponent(fileName)
                        guard fileManager.fileExists(atPath: source.path) else { continue }
                        let target = destination.appendingPathComponent("\(sessionDir.lastPathComponent)-\(fileName)")
                        try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: source, destination: target, warnings: &warnings)
                        copied = true
                    }
                }
            }
        }
        if copied {
            try writeRedactedText(
                "Performance evidence copied from .panino/performance, including sessions, GC logs, applied/user profiles, candidates, and cooldowns.",
                to: destination.appendingPathComponent("README.txt")
            )
        }
    }

    static func writeRedactedJSON<T: Encodable>(_ value: T, to destination: URL) throws {
        let data = try JSONEncoder.panino.encode(value)
        try writeRedactedData(data, to: destination)
    }

    static func writeRedactedText(_ text: String, to destination: URL) throws {
        let data = Data(DiagnosticRedactor.redact(text).utf8)
        try writeReplacingExisting(fileManager: .default, data: data, destination: destination)
    }

    static func copyRedactedDiagnosticArtifact(fileManager: FileManager, source: URL, destination: URL, warnings: inout [String]) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else { return }
        if isDirectory.boolValue {
            try copyDirectoryContents(fileManager: fileManager, source: source, destination: destination, warnings: &warnings)
            return
        }
        let data = try Data(contentsOf: source)
        guard DiagnosticRedactor.canRedact(data) else {
            warnings.append("Skipped non-text diagnostic artifact: \(DiagnosticRedactor.redact(source.path))")
            return
        }
        try writeReplacingExisting(fileManager: fileManager, data: DiagnosticRedactor.redactedData(data), destination: destination)
    }

    private static func diagnosticURL(basePath: String, relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(URL(fileURLWithPath: basePath, isDirectory: true)) { url, component in
                url.appendingPathComponent(String(component))
            }
    }

    private static func copyDirectoryContents(fileManager: FileManager, source: URL, destination: URL, warnings: inout [String]) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let entries = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for entry in entries {
            let target = destination.appendingPathComponent(entry.lastPathComponent)
            try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: entry, destination: target, warnings: &warnings)
        }
    }

    private static func writeRedactedData(_ data: Data, to destination: URL) throws {
        let redacted = DiagnosticRedactor.redactedData(data)
        try writeReplacingExisting(fileManager: .default, data: redacted, destination: destination)
    }

    private static func writeReplacingExisting(fileManager: FileManager, data: Data, destination: URL) throws {
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try data.write(to: destination, options: .atomic)
    }
}
