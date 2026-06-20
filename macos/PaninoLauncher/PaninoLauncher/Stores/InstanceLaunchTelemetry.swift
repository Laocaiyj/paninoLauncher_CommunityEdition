import Foundation

private struct GraphicsTuningDiagnostic: Codable {
    let tuning: CoreResolvedGraphicsTuning
}

enum InstanceLaunchTelemetry {
    static func readResolvedJvmTuning(gameDir: String?) -> CoreResolvedJvmTuning? {
        guard let gameDir = gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: gameDir, isDirectory: true)
            .appendingPathComponent("downloads", isDirectory: true)
            .appendingPathComponent("jvm-tuning.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.panino.decode(CoreResolvedJvmTuning.self, from: data)
    }

    static func readResolvedGraphicsTuning(gameDir: String?) -> CoreResolvedGraphicsTuning? {
        guard let gameDir = gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: gameDir, isDirectory: true)
            .appendingPathComponent("downloads", isDirectory: true)
            .appendingPathComponent("graphics-tuning.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let wrapped = try? JSONDecoder.panino.decode(GraphicsTuningDiagnostic.self, from: data) {
            return wrapped.tuning
        }
        return try? JSONDecoder.panino.decode(CoreResolvedGraphicsTuning.self, from: data)
    }

    static func makeJvmTuningSnapshot(
        for instance: GameInstance,
        task: TaskSnapshot?,
        state: LaunchHistoryState,
        startedAt: Date?,
        finishedAt: Date?,
        resolved: CoreResolvedJvmTuning?
    ) -> JvmTuningSnapshot {
        let finalArgs = resolved?.jvmArgs ?? fallbackJvmArgs(for: instance)
        let failureText = [
            task?.errorCode,
            task?.errorDetail,
            task?.message
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return JvmTuningSnapshot(
            id: UUID(),
            instanceId: instance.id,
            recordedAt: finishedAt ?? Date(),
            startedAt: startedAt,
            finishedAt: finishedAt,
            state: state,
            memoryPolicy: instance.memoryPolicy,
            jvmProfile: instance.jvmProfile,
            configuredMemoryMb: instance.memoryMb,
            customMemoryMb: instance.customMemoryMb,
            customJvmArgs: splitJvmArguments(instance.customJvmArguments),
            finalXmsMb: resolved?.xmsMb,
            finalXmxMb: resolved?.xmxMb,
            finalGc: detectGC(from: finalArgs),
            finalJvmArgs: finalArgs,
            systemMemoryMb: resolved?.systemMemoryMb,
            packScale: resolved?.packScale,
            tuningSummary: resolved?.summary,
            warningCodes: resolved?.warnings.map(\.code) ?? [],
            exitCode: task.flatMap(launchExitCode),
            heapOutOfMemory: looksLikeHeapOOM(failureText),
            nativeOutOfMemory: looksLikeNativeOOM(failureText),
            gcOverheadLimit: failureText.contains("gc overhead")
        )
    }

    static func makeGraphicsTuningSnapshot(
        for instance: GameInstance,
        task: TaskSnapshot?,
        state: LaunchHistoryState,
        startedAt: Date?,
        finishedAt: Date?,
        resolved: CoreResolvedGraphicsTuning?
    ) -> GraphicsTuningSnapshot {
        let failureText = [
            task?.errorCode,
            task?.errorDetail,
            task?.message
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        let quickExit = finishedAt.map { end in
            startedAt.map { end.timeIntervalSince($0) < 30 } ?? false
        } ?? false
        return GraphicsTuningSnapshot(
            id: UUID(),
            instanceId: instance.id,
            recordedAt: finishedAt ?? Date(),
            startedAt: startedAt,
            finishedAt: finishedAt,
            state: state,
            graphicsProfile: instance.graphicsProfile,
            effectiveProfile: resolved?.effectiveProfile,
            hardwareTier: resolved?.hardwareTier,
            retinaPolicy: resolved?.retinaPolicy,
            currentOptions: resolved?.currentOptions ?? [:],
            recommendedOptions: resolved?.recommendedOptions ?? [:],
            patchChanges: resolved?.optionsPatch.changes ?? [],
            tuningSummary: resolved?.summary,
            warningCodes: resolved?.warnings.map(\.code) ?? [],
            backupPath: resolved?.backupPath,
            canRollback: resolved?.canRollback ?? false,
            quickExit: quickExit,
            crashed: state == .failed,
            renderRelatedError: looksLikeRenderError(failureText)
        )
    }

    private static func fallbackJvmArgs(for instance: GameInstance) -> [String] {
        let memoryMb = instance.customMemoryMb ?? instance.memoryMb
        var args = ["-Xms\(memoryMb)m", "-Xmx\(memoryMb)m"]
        args.append(contentsOf: splitJvmArguments(instance.customJvmArguments))
        return args
    }

    private static func detectGC(from args: [String]) -> String? {
        if args.contains(where: { $0.contains("UseZGC") }) { return "ZGC" }
        if args.contains(where: { $0.contains("UseG1GC") }) { return "G1GC" }
        if args.contains(where: { $0.contains("UseShenandoahGC") }) { return "Shenandoah" }
        if args.contains(where: { $0.contains("UseParallelGC") }) { return "Parallel" }
        if args.contains(where: { $0.contains("UseSerialGC") }) { return "Serial" }
        return nil
    }

    private static func launchExitCode(from task: TaskSnapshot) -> Int? {
        let source = [task.errorCode, task.errorDetail, task.message]
            .compactMap { $0 }
            .joined(separator: " ")
        for pattern in ["exit[_ -]?code[^-0-9]*(-?[0-9]+)", "exit[^-0-9]+(-?[0-9]+)"] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            guard let match = regex.firstMatch(in: source, range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: source)
            else {
                continue
            }
            return Int(source[valueRange])
        }
        return nil
    }

    private static func looksLikeHeapOOM(_ text: String) -> Bool {
        text.contains("outofmemoryerror")
            || text.contains("java heap space")
            || text.contains("heap oom")
    }

    private static func looksLikeNativeOOM(_ text: String) -> Bool {
        text.contains("native memory")
            || text.contains("unable to allocate")
            || text.contains("os::commit_memory")
            || text.contains("mmap")
    }

    private static func looksLikeRenderError(_ text: String) -> Bool {
        ["opengl", "glfw", "render", "renderer", "gpu", "shader", "iris", "sodium", "metal"].contains {
            text.contains($0)
        }
    }
}
