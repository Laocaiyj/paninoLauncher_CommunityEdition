import Foundation

extension LaunchDashboard {
    func backupSaves(for instance: GameInstance) {
        let source = URL(fileURLWithPath: instance.gameDirectory, isDirectory: true)
            .appendingPathComponent("saves", isDirectory: true)
            .path
        runArchiveOperation(
            instance: instance,
            kind: "backup",
            sourcePath: source,
            backupCategory: "saves",
            title: localizedString(theme.language, english: "Backup Saves", chinese: "备份存档", italian: "Backup salvataggi", french: "Sauvegarder", spanish: "Respaldar partidas"),
            filenameSuffix: "saves"
        )
    }

    func exportInstance(for instance: GameInstance) {
        runArchiveOperation(
            instance: instance,
            kind: "export",
            sourcePath: instance.gameDirectory,
            backupCategory: "instances",
            title: localizedString(theme.language, english: "Export Instance", chinese: "导出实例", italian: "Esporta istanza", french: "Exporter instance", spanish: "Exportar instancia"),
            filenameSuffix: "instance"
        )
    }

    private func runArchiveOperation(
        instance: GameInstance,
        kind: String,
        sourcePath: String,
        backupCategory: String,
        title: String,
        filenameSuffix: String
    ) {
        guard !sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            taskCenterStore.upsertLocal(
                kind: kind,
                name: title,
                state: .failed,
                progress: 0,
                errorCode: "missing_source",
                message: "Archive source path is missing."
            )
            return
        }

        let taskID = UUID().uuidString
        taskCenterStore.upsertLocal(
            id: taskID,
            kind: kind,
            name: title,
            version: instance.minecraftVersion,
            state: .running,
            progress: 0.1,
            currentFile: sourcePath,
            message: "Core preflight queued."
        )

        Task {
            do {
                let targetPath = try archiveTargetPath(
                    instance: instance,
                    category: backupCategory,
                    suffix: filenameSuffix
                )
                let preflight = try await viewModel.exportBackupPreflight(
                    for: instance,
                    kind: kind,
                    targetPath: targetPath
                )
                guard preflight.allowed else {
                    await MainActor.run {
                        _ = taskCenterStore.upsertLocal(
                            id: taskID,
                            kind: kind,
                            name: title,
                            version: instance.minecraftVersion,
                            state: .failed,
                            progress: 1,
                            currentFile: sourcePath,
                            errorCode: "preflight_blocked",
                            message: preflight.blockingReasons.joined(separator: ", ")
                        )
                    }
                    return
                }

                let response = try await viewModel.archiveLocalDirectory(
                    sourcePath: sourcePath,
                    targetPath: targetPath
                )
                await MainActor.run {
                    let warnings = preflight.warnings.isEmpty ? "" : " Warnings: \(preflight.warnings.joined(separator: ", "))"
                    taskCenterStore.upsertLocal(
                        id: taskID,
                        kind: kind,
                        name: title,
                        version: instance.minecraftVersion,
                        state: .succeeded,
                        progress: 1,
                        currentFile: response.path ?? targetPath,
                        message: "\(response.message): \(response.path ?? targetPath).\(warnings)"
                    )
                    viewModel.appendLog("\(title) completed: \(response.path ?? targetPath)")
                }
            } catch {
                await MainActor.run {
                    taskCenterStore.upsertLocal(
                        id: taskID,
                        kind: kind,
                        name: title,
                        version: instance.minecraftVersion,
                        state: .failed,
                        progress: 1,
                        currentFile: sourcePath,
                        errorCode: "archive_failed",
                        message: error.localizedDescription
                    )
                    viewModel.appendLog("\(title) failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func archiveTargetPath(instance: GameInstance, category: String, suffix: String) throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "\(safeArchiveName(instance.name))-\(suffix)-\(formatter.string(from: Date())).zip"
        return try LauncherPaths.backupsDirectory(category: category)
            .appendingPathComponent(filename)
            .path
    }

    private func safeArchiveName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        var result = ""
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "panino-instance" : trimmed
    }
}
