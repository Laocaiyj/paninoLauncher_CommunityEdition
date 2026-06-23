import Foundation

enum LauncherTaskFailureSnapshots {
    static func installFailure(
        version: String,
        gameDir: String?,
        loader: LoaderKind?,
        shaderLoader: String?,
        error: Error
    ) -> TaskSnapshot {
        let rawDetail = error.localizedDescription
        let blocked = installPreflightBlockedError(from: error)
        let blockedReason = blocked?.blockedReasons?.first ?? blocked?.preflight?.blockedReasons.first
        let message = blockedReason ?? rawDetail
        let detail = [
            "requestedMinecraftVersion=\(version)",
            "requestedGameDir=\(gameDir ?? "-")",
            "requestedLoader=\(loader?.rawValue ?? "-")",
            "requestedShaderLoader=\(shaderLoader ?? "-")",
            "loaderVersion=\(blocked?.preflight?.loaderVersion ?? "-")",
            "loaderProfileId=\(blocked?.preflight?.loaderProfileId ?? "-")",
            "shaderProjects=\(blocked?.preflight?.shaderProjects.joined(separator: ",") ?? "-")",
            "blockedReasons=\((blocked?.blockedReasons ?? blocked?.preflight?.blockedReasons ?? []).joined(separator: ","))",
            "rawError=\(rawDetail)"
        ].joined(separator: "\n")
        return TaskSnapshot.failedInstall(
            version: version,
            gameDir: gameDir,
            requestedLoader: loader?.rawValue,
            requestedShaderLoader: shaderLoader,
            message: blocked?.diagnostic?.userSummary ?? message,
            errorCode: blocked?.diagnostic?.code ?? blockedReason.flatMap(errorCodePrefix) ?? blocked?.error ?? "install_failed",
            errorDetail: blocked?.diagnostic?.developerDetail ?? detail,
            diagnostic: blocked?.diagnostic,
            diagnostics: blocked?.structuredDiagnostics ?? blocked?.diagnostic.map { [$0] } ?? []
        )
    }

    static func missingTaskSnapshot(taskId: String, error: Error, currentTask: TaskSnapshot?) -> TaskSnapshot? {
        guard case LauncherApiError.unexpectedStatus(404, _) = error else { return nil }
        guard let task = currentTask, task.taskId == taskId else { return nil }
        let detail = [
            "taskId=\(taskId)",
            "lastKnownState=\(task.state.rawValue)",
            "rawError=\(error.localizedDescription)"
        ].joined(separator: "\n")
        return TaskSnapshot(
            taskId: task.taskId,
            kind: task.kind,
            version: task.version,
            gameDir: task.gameDir,
            requestedLoader: task.requestedLoader,
            requestedShaderLoader: task.requestedShaderLoader,
            state: .failed,
            message: "Task was interrupted before Core reported a final state.",
            errorCode: "task_not_found",
            errorDetail: detail,
            diagnostic: task.diagnostic,
            diagnostics: task.diagnostics,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            finishedAt: task.updatedAt,
            progress: task.progress
        )
    }

    private static func installPreflightBlockedError(from error: Error) -> CoreInstallPreflightBlockedError? {
        guard case let LauncherApiError.unexpectedStatus(_, body) = error else { return nil }
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONDecoder.panino.decode(CoreInstallPreflightBlockedError.self, from: data)
    }

    private static func errorCodePrefix(_ value: String) -> String? {
        let prefix = value.split(separator: ":", maxSplits: 1).first.map(String.init)
        return prefix?.isEmpty == false ? prefix : nil
    }
}
