import Foundation

@MainActor
enum DiagnosticsPerformanceEvidenceWriter {
    static func copy(
        tasks: [TaskRecord],
        fileManager: FileManager,
        destination: URL,
        warnings: inout [String]
    ) throws {
        var copied = false
        for root in performanceRoots(tasks: tasks, fileManager: fileManager) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            copied = try copyStandardEvidence(
                root: root,
                fileManager: fileManager,
                destination: destination,
                warnings: &warnings
            ) || copied
            copied = try copyProfileEvidence(
                root: root,
                fileManager: fileManager,
                destination: destination,
                warnings: &warnings
            ) || copied
            copied = try copySessionEvidence(
                root: root,
                fileManager: fileManager,
                destination: destination,
                warnings: &warnings
            ) || copied
        }

        if copied {
            try DiagnosticsPackageWriter.writeRedactedText(
                "Performance evidence copied from .panino/performance, including sessions, GC logs, applied/user profiles, candidates, and cooldowns.",
                to: destination.appendingPathComponent("README.txt")
            )
        }
    }

    private static func performanceRoots(tasks: [TaskRecord], fileManager: FileManager) -> [URL] {
        orderedGameDirs(tasks: tasks)
            .map {
                URL(fileURLWithPath: $0, isDirectory: true)
                    .appendingPathComponent(".panino", isDirectory: true)
                    .appendingPathComponent("performance", isDirectory: true)
            }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    private static func orderedGameDirs(tasks: [TaskRecord]) -> [String] {
        let taskDirs = tasks
            .compactMap(\.gameDir)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: taskDirs + [LauncherSettings.defaultMinecraftDirectory])) as? [String] ?? []
    }

    private static func copyStandardEvidence(
        root: URL,
        fileManager: FileManager,
        destination: URL,
        warnings: inout [String]
    ) throws -> Bool {
        var copied = false
        for relativePath in [
            "profiles/applied.json",
            "profiles/user-override.json",
            "experiments/cooldowns"
        ] {
            let source = diagnosticURL(basePath: root.path, relativePath: relativePath)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = destination.appendingPathComponent(relativePath.replacingOccurrences(of: "/", with: "-"))
            try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                fileManager: fileManager,
                source: source,
                destination: target,
                warnings: &warnings
            )
            copied = true
        }
        return copied
    }

    private static func copyProfileEvidence(
        root: URL,
        fileManager: FileManager,
        destination: URL,
        warnings: inout [String]
    ) throws -> Bool {
        var copied = false
        let profilesRoot = root.appendingPathComponent("profiles", isDirectory: true)
        if fileManager.fileExists(atPath: profilesRoot.path) {
            try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
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
                try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: profileFile,
                    destination: target,
                    warnings: &warnings
                )
                copied = true
            }
        }
        return copied
    }

    private static func copySessionEvidence(
        root: URL,
        fileManager: FileManager,
        destination: URL,
        warnings: inout [String]
    ) throws -> Bool {
        var copied = false
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        if fileManager.fileExists(atPath: sessionsRoot.path) {
            try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                fileManager: fileManager,
                source: sessionsRoot,
                destination: destination.appendingPathComponent("sessions", isDirectory: true),
                warnings: &warnings
            )
            copied = true
        }
        if let sessionDirs = try? fileManager.contentsOfDirectory(
            at: sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for sessionDir in latestSessionDirectories(sessionDirs) {
                for fileName in ["performance-session.json", "gc.log"] {
                    let source = sessionDir.appendingPathComponent(fileName)
                    guard fileManager.fileExists(atPath: source.path) else { continue }
                    let target = destination.appendingPathComponent("\(sessionDir.lastPathComponent)-\(fileName)")
                    try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                        fileManager: fileManager,
                        source: source,
                        destination: target,
                        warnings: &warnings
                    )
                    copied = true
                }
            }
        }
        return copied
    }

    private static func latestSessionDirectories(_ urls: [URL]) -> ArraySlice<URL> {
        urls.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
        .prefix(3)
    }

    private static func diagnosticURL(basePath: String, relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(URL(fileURLWithPath: basePath, isDirectory: true)) { url, component in
                url.appendingPathComponent(String(component))
            }
    }
}
