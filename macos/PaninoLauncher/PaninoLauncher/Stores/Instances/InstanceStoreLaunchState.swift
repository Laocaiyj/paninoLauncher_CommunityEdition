import Foundation

@MainActor
extension InstanceStore {
    func markSelectedLaunched() {
        guard let selectedID = selectedInstance?.id,
              let index = instances.firstIndex(where: { $0.id == selectedID }) else { return }
        activeLaunchInstanceID = selectedID
        let startedAt = Date()
        instances[index].lastLaunchedAt = startedAt
        instances[index].lastLaunchDuration = nil
        instances[index].lastLaunchState = .running
        instances[index].launchCount += 1
        instances[index].status = .running
        instances[index].lastJvmTuningSnapshot = InstanceLaunchTelemetry.makeJvmTuningSnapshot(
            for: instances[index],
            task: nil,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: nil
        )
        instances[index].lastGraphicsTuningSnapshot = InstanceLaunchTelemetry.makeGraphicsTuningSnapshot(
            for: instances[index],
            task: nil,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: InstanceLaunchTelemetry.readResolvedGraphicsTuning(gameDir: instances[index].gameDirectory)
        )
    }

    func markLaunchStarted(from task: TaskSnapshot) {
        guard task.kind == "launch", task.state.isActive,
              let index = launchInstanceIndex(for: task, preferActive: false)
        else { return }
        let targetID = instances[index].id
        if activeLaunchInstanceID == targetID, instances[index].lastLaunchState == .running {
            return
        }

        activeLaunchInstanceID = targetID
        let startedAt = Self.date(from: task.createdAt) ?? Date()
        instances[index].lastLaunchedAt = startedAt
        instances[index].lastLaunchDuration = nil
        instances[index].lastLaunchState = .running
        instances[index].launchCount += 1
        instances[index].status = .running
        instances[index].lastJvmTuningSnapshot = InstanceLaunchTelemetry.makeJvmTuningSnapshot(
            for: instances[index],
            task: task,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: InstanceLaunchTelemetry.readResolvedJvmTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
        )
        instances[index].lastGraphicsTuningSnapshot = InstanceLaunchTelemetry.makeGraphicsTuningSnapshot(
            for: instances[index],
            task: task,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: InstanceLaunchTelemetry.readResolvedGraphicsTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
        )
    }

    func markSelectedLaunchFinished(success: Bool) {
        let targetID = activeLaunchInstanceID ?? selectedInstance?.id
        activeLaunchInstanceID = nil
        guard let targetID,
              let index = instances.firstIndex(where: { $0.id == targetID }) else { return }
        if success, instances[index].status == .running, let startedAt = instances[index].lastLaunchedAt {
            let elapsed = max(Date().timeIntervalSince(startedAt), 0)
            instances[index].lastLaunchDuration = elapsed
            instances[index].totalPlaySeconds = (instances[index].totalPlaySeconds ?? 0) + elapsed
        }
        if !success {
            instances[index].lastLaunchDuration = nil
        }
        instances[index].lastLaunchState = success ? .succeeded : .failed
        instances[index].status = success ? .ready : .failed
        let resolved = InstanceLaunchTelemetry.readResolvedJvmTuning(gameDir: instances[index].gameDirectory)
        let snapshot = InstanceLaunchTelemetry.makeJvmTuningSnapshot(
            for: instances[index],
            task: nil,
            state: success ? .succeeded : .failed,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: Date(),
            resolved: resolved
        )
        instances[index].lastJvmTuningSnapshot = snapshot
        let graphicsSnapshot = InstanceLaunchTelemetry.makeGraphicsTuningSnapshot(
            for: instances[index],
            task: nil,
            state: success ? .succeeded : .failed,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: Date(),
            resolved: InstanceLaunchTelemetry.readResolvedGraphicsTuning(gameDir: instances[index].gameDirectory)
        )
        instances[index].lastGraphicsTuningSnapshot = graphicsSnapshot
        if success {
            instances[index].lastKnownGoodJvmTuning = snapshot
            instances[index].lastKnownGoodGraphicsTuning = graphicsSnapshot
        }
    }

    func markLaunchFinished(from task: TaskSnapshot) {
        guard task.kind == "launch", task.state.isTerminal,
              let index = launchInstanceIndex(for: task, preferActive: true)
        else { return }
        let success = task.state == .succeeded
        let wasRunning = instances[index].lastLaunchState == .running
        let finishedAt = task.finishedAt.flatMap(Self.date(from:))
            ?? Self.date(from: task.updatedAt)
            ?? Date()

        if success, wasRunning, let startedAt = instances[index].lastLaunchedAt {
            let elapsed = max(finishedAt.timeIntervalSince(startedAt), 0)
            instances[index].lastLaunchDuration = elapsed
            instances[index].totalPlaySeconds = (instances[index].totalPlaySeconds ?? 0) + elapsed
        } else if !success {
            instances[index].lastLaunchDuration = nil
        }

        instances[index].lastLaunchState = success ? .succeeded : .failed
        instances[index].status = success ? .ready : .failed
        let resolved = InstanceLaunchTelemetry.readResolvedJvmTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
        let state: LaunchHistoryState = task.state == .cancelled ? .cancelled : (success ? .succeeded : .failed)
        let snapshot = InstanceLaunchTelemetry.makeJvmTuningSnapshot(
            for: instances[index],
            task: task,
            state: state,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: finishedAt,
            resolved: resolved
        )
        instances[index].lastJvmTuningSnapshot = snapshot
        let graphicsSnapshot = InstanceLaunchTelemetry.makeGraphicsTuningSnapshot(
            for: instances[index],
            task: task,
            state: state,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: finishedAt,
            resolved: InstanceLaunchTelemetry.readResolvedGraphicsTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
        )
        instances[index].lastGraphicsTuningSnapshot = graphicsSnapshot
        if success {
            instances[index].lastKnownGoodJvmTuning = snapshot
            instances[index].lastKnownGoodGraphicsTuning = graphicsSnapshot
        }
        if activeLaunchInstanceID == instances[index].id {
            activeLaunchInstanceID = nil
        }
    }

    private func launchInstanceIndex(for task: TaskSnapshot, preferActive: Bool) -> Int? {
        if preferActive,
           let activeLaunchInstanceID,
           let index = instances.firstIndex(where: { $0.id == activeLaunchInstanceID }) {
            return index
        }

        if let gameDir = task.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty {
            let key = InstanceLocalCatalog.key(version: task.version, gameDirectory: gameDir)
            if let index = instances.firstIndex(where: {
                InstanceLocalCatalog.key(version: $0.minecraftVersion, gameDirectory: InstanceLocalCatalog.effectiveGameDirectory(for: $0)) == key
            }) {
                return index
            }
        }

        if let selectedID = selectedInstanceID,
           let index = instances.firstIndex(where: { $0.id == selectedID && $0.minecraftVersion == task.version }) {
            return index
        }
        return instances.firstIndex { $0.minecraftVersion == task.version }
    }

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
