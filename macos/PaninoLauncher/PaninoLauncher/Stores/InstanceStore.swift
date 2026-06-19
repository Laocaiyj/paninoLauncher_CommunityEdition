import Foundation
import SwiftUI

private struct GraphicsTuningDiagnostic: Codable {
    let tuning: CoreResolvedGraphicsTuning
}

@MainActor
final class InstanceStore: ObservableObject {
    @Published var instances: [GameInstance] = [] {
        didSet { save() }
    }

    @Published var selectedInstanceID: UUID? {
        didSet { SettingsStore.set(selectedInstanceID?.uuidString ?? "", forKey: "Instances.SelectedID") }
    }

    @Published private(set) var storageStatus = "Local game instances not loaded"
    private var activeLaunchInstanceID: UUID?

    init() {
        load()
    }

    var selectedInstance: GameInstance? {
        instances.first { $0.id == selectedInstanceID } ?? instances.first
    }

    var selectedInstanceBinding: Binding<GameInstance>? {
        guard let selectedID = selectedInstance?.id else {
            return nil
        }
        return Binding(
            get: {
                self.instances.first { $0.id == selectedID }
                    ?? self.selectedInstance
                    ?? Self.placeholderInstance
            },
            set: { newValue in
                if let index = self.instances.firstIndex(where: { $0.id == selectedID }) {
                    self.instances[index] = newValue
                }
            }
        )
    }

    func createInstance(settings: LauncherSettings) {
        storageStatus = "Direct game configuration creation is disabled. Install Minecraft from Get; local instances appear after files are installed."
    }

    func insertConfiguredInstance(_ instance: GameInstance) {
        instances.insert(instance, at: 0)
        selectedInstanceID = instance.id
    }

    func duplicateSelected() {
        storageStatus = "Duplicate configurations are disabled. Install another local instance from Get and rename it after installation."
    }

    func deleteSelected() {
        guard let selectedID = selectedInstance?.id else { return }
        instances.removeAll { $0.id == selectedID }
        selectedInstanceID = instances.first?.id
    }

    func remove(_ instance: GameInstance) {
        instances.removeAll { $0.id == instance.id }
        if selectedInstanceID == instance.id {
            selectedInstanceID = instances.first?.id
        }
    }

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
        instances[index].lastJvmTuningSnapshot = makeJvmTuningSnapshot(
            for: instances[index],
            task: nil,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: nil
        )
        instances[index].lastGraphicsTuningSnapshot = makeGraphicsTuningSnapshot(
            for: instances[index],
            task: nil,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: readResolvedGraphicsTuning(gameDir: instances[index].gameDirectory)
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
        instances[index].lastJvmTuningSnapshot = makeJvmTuningSnapshot(
            for: instances[index],
            task: task,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: readResolvedJvmTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
        )
        instances[index].lastGraphicsTuningSnapshot = makeGraphicsTuningSnapshot(
            for: instances[index],
            task: task,
            state: .running,
            startedAt: startedAt,
            finishedAt: nil,
            resolved: readResolvedGraphicsTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
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
        let resolved = readResolvedJvmTuning(gameDir: instances[index].gameDirectory)
        let snapshot = makeJvmTuningSnapshot(
            for: instances[index],
            task: nil,
            state: success ? .succeeded : .failed,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: Date(),
            resolved: resolved
        )
        instances[index].lastJvmTuningSnapshot = snapshot
        let graphicsSnapshot = makeGraphicsTuningSnapshot(
            for: instances[index],
            task: nil,
            state: success ? .succeeded : .failed,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: Date(),
            resolved: readResolvedGraphicsTuning(gameDir: instances[index].gameDirectory)
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
        let resolved = readResolvedJvmTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
        let state: LaunchHistoryState = task.state == .cancelled ? .cancelled : (success ? .succeeded : .failed)
        let snapshot = makeJvmTuningSnapshot(
            for: instances[index],
            task: task,
            state: state,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: finishedAt,
            resolved: resolved
        )
        instances[index].lastJvmTuningSnapshot = snapshot
        let graphicsSnapshot = makeGraphicsTuningSnapshot(
            for: instances[index],
            task: task,
            state: state,
            startedAt: instances[index].lastLaunchedAt,
            finishedAt: finishedAt,
            resolved: readResolvedGraphicsTuning(gameDir: task.gameDir ?? instances[index].gameDirectory)
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

    func setFavorite(_ instanceID: UUID, isFavorite: Bool) {
        guard let index = instances.firstIndex(where: { $0.id == instanceID }) else { return }
        instances[index].isFavorite = isFavorite
    }

    func setHiddenFromRecent(_ instanceID: UUID, hidden: Bool) {
        guard let index = instances.firstIndex(where: { $0.id == instanceID }) else { return }
        instances[index].isHiddenFromRecent = hidden
    }

    private func load() {
        do {
            let fileURL = try instancesURL()
            let selectedID = SettingsStore.string(forKey: "Instances.SelectedID", default: "")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                instances = try JSONDecoder.panino
                    .decode([GameInstance].self, from: data)
                    .filter(isConcreteLocalInstance)
            }
            selectedInstanceID = UUID(uuidString: selectedID) ?? instances.first?.id
            storageStatus = "Local game instances loaded from \(fileURL.path)"
        } catch {
            instances = []
            selectedInstanceID = instances.first?.id
            storageStatus = "Local game instance load failed: \(error.localizedDescription)"
        }
    }

    func reconcileInstalledInstances(_ installedInstances: [CoreInstalledMinecraftInstance], settings: LauncherSettings) {
        let isolatedLocal = installedInstances.filter { !$0.archived && isIsolatedGameDirectory($0.gameDir) }
        let legacyMigratable = installedInstances.compactMap { installed -> CoreInstalledMinecraftInstance? in
            guard installed.versionJson,
                  installed.clientJar,
                  !installed.archived,
                  !isIsolatedGameDirectory(installed.gameDir),
                  let isolatedDirectory = isolatedGameDirectory(forVersion: installed.versionId)
            else {
                return nil
            }
            return CoreInstalledMinecraftInstance(
                versionId: installed.versionId,
                minecraftVersion: installed.minecraftVersion,
                loader: installed.loader,
                loaderVersion: installed.loaderVersion,
                name: installed.name,
                gameDir: isolatedDirectory,
                versionJson: false,
                clientJar: false,
                diskUsageBytes: installed.diskUsageBytes,
                archived: false,
                archivePath: nil
            )
        }
        let localCandidates = isolatedLocal + legacyMigratable
        let legacySharedCount = installedInstances.filter { $0.versionJson && $0.clientJar && !$0.archived && !isIsolatedGameDirectory($0.gameDir) }.count
        let installedKeys = Set(localCandidates.map { instanceKey(version: $0.versionId, gameDirectory: $0.gameDir) })
        var next = instances.filter { instance in
            installedKeys.contains(instanceKey(version: instance.minecraftVersion, gameDirectory: effectiveGameDirectory(for: instance)))
        }

        for installed in localCandidates {
            let key = instanceKey(version: installed.versionId, gameDirectory: installed.gameDir)
            if let index = next.firstIndex(where: { instanceKey(version: $0.minecraftVersion, gameDirectory: effectiveGameDirectory(for: $0)) == key }) {
                if let loader = installed.loader.flatMap(LoaderKind.init(rawValue:)) {
                    next[index].loader = loader
                }
                if let loaderVersion = installed.loaderVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !loaderVersion.isEmpty {
                    next[index].loaderVersion = loaderVersion
                }
                if let minecraftVersion = installed.minecraftVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !minecraftVersion.isEmpty {
                    next[index].baseMinecraftVersion = minecraftVersion
                }
                next[index].status = installed.versionJson && installed.clientJar ? .ready : .notInstalled
                continue
            }
            next.append(installed.asGameInstance(settings: settings, existingNames: Set(next.map(\.name))))
        }

        next = normalizeDuplicateNames(next)
        if next != instances {
            instances = next.sorted(by: instanceSort)
        }
        if selectedInstanceID == nil || !instances.contains(where: { $0.id == selectedInstanceID }) {
            selectedInstanceID = instances.first?.id
        }
        storageStatus = legacySharedCount > 0
            ? "Synced \(instances.count) local game instances; \(legacySharedCount) legacy installs require isolation"
            : "Synced \(instances.count) isolated local game instances"
    }

    private func save() {
        do {
            let fileURL = try instancesURL()
            let data = try JSONEncoder.panino.encode(instances)
            try data.write(to: fileURL, options: .atomic)
            storageStatus = "Local game instances saved at \(fileURL.path)"
        } catch {
            storageStatus = "Local game instance save failed: \(error.localizedDescription)"
        }
    }

    private func instancesURL() throws -> URL {
        let directory = try LauncherPaths.appSupportDirectory()
        return directory.appendingPathComponent("instances.json")
    }

    private func effectiveGameDirectory(for instance: GameInstance) -> String {
        instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isIsolatedGameDirectory(_ path: String) -> Bool {
        guard let root = try? LauncherPaths.gameConfigurationsDirectory()
            .standardizedFileURL
        else {
            return false
        }
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        let rootPath = root.path
        return standardized == rootPath || standardized.hasPrefix(rootPath + "/")
    }

    private func isolatedGameDirectory(forVersion version: String) -> String? {
        guard let root = try? LauncherPaths.gameConfigurationsDirectory()
            .standardizedFileURL
        else {
            return nil
        }
        return root
            .appendingPathComponent(safeFileComponent(version), isDirectory: true)
            .path
    }

    private func isConcreteLocalInstance(_ instance: GameInstance) -> Bool {
        let gameDirectory = effectiveGameDirectory(for: instance)
        guard !gameDirectory.isEmpty,
              isIsolatedGameDirectory(gameDirectory)
        else {
            return false
        }
        return FileManager.default.fileExists(atPath: gameDirectory)
    }

    private func instanceKey(version: String, gameDirectory: String) -> String {
        let standardized = URL(fileURLWithPath: gameDirectory, isDirectory: true).standardizedFileURL.path
        return "\(version)|\(standardized)"
    }

    private func launchInstanceIndex(for task: TaskSnapshot, preferActive: Bool) -> Int? {
        if preferActive,
           let activeLaunchInstanceID,
           let index = instances.firstIndex(where: { $0.id == activeLaunchInstanceID }) {
            return index
        }

        if let gameDir = task.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty {
            let key = instanceKey(version: task.version, gameDirectory: gameDir)
            if let index = instances.firstIndex(where: {
                instanceKey(version: $0.minecraftVersion, gameDirectory: effectiveGameDirectory(for: $0)) == key
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

    private func readResolvedJvmTuning(gameDir: String?) -> CoreResolvedJvmTuning? {
        guard let gameDir = gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: gameDir, isDirectory: true)
            .appendingPathComponent("downloads", isDirectory: true)
            .appendingPathComponent("jvm-tuning.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.panino.decode(CoreResolvedJvmTuning.self, from: data)
    }

    private func readResolvedGraphicsTuning(gameDir: String?) -> CoreResolvedGraphicsTuning? {
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

    private func makeJvmTuningSnapshot(
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
            finalGc: Self.detectGC(from: finalArgs),
            finalJvmArgs: finalArgs,
            systemMemoryMb: resolved?.systemMemoryMb,
            packScale: resolved?.packScale,
            tuningSummary: resolved?.summary,
            warningCodes: resolved?.warnings.map(\.code) ?? [],
            exitCode: task.flatMap(Self.launchExitCode),
            heapOutOfMemory: Self.looksLikeHeapOOM(failureText),
            nativeOutOfMemory: Self.looksLikeNativeOOM(failureText),
            gcOverheadLimit: failureText.contains("gc overhead")
        )
    }

    private func makeGraphicsTuningSnapshot(
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
            renderRelatedError: Self.looksLikeRenderError(failureText)
        )
    }

    private func fallbackJvmArgs(for instance: GameInstance) -> [String] {
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

    private func normalizeDuplicateNames(_ source: [GameInstance]) -> [GameInstance] {
        var counts: [String: Int] = [:]
        return source.map { instance in
            var next = instance
            let count = counts[instance.name, default: 0] + 1
            counts[instance.name] = count
            if count > 1 {
                next.name = "\(instance.name) \(count)"
            }
            return next
        }
    }

    private func instanceSort(_ lhs: GameInstance, _ rhs: GameInstance) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
        if lhs.lastLaunchedAt != rhs.lastLaunchedAt {
            return (lhs.lastLaunchedAt ?? .distantPast) > (rhs.lastLaunchedAt ?? .distantPast)
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func safeFileComponent(_ value: String) -> String {
        SafeFileComponent.sanitize(value)
    }

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static var placeholderInstance: GameInstance {
        GameInstance(
            id: UUID(),
            name: "No Installed Instance",
            iconName: "shippingbox.fill",
            coverPath: "",
            minecraftVersion: "",
            gameDirectory: "",
            javaPath: "",
            memoryMb: SettingsStore.memoryMb,
            loader: nil,
            loaderVersion: nil,
            jvmArguments: "",
            preLaunchBehavior: "Install missing files",
            group: "Default",
            isFavorite: false,
            lastLaunchedAt: nil,
            totalPlaySeconds: nil,
            status: .failed
        )
    }
}

@MainActor
private extension CoreInstalledMinecraftInstance {
    func asGameInstance(settings: LauncherSettings, existingNames: Set<String>) -> GameInstance {
        let baseName = displayNameFromDirectory()
        return GameInstance(
            id: UUID(),
            name: uniqueName(baseName, existingNames: existingNames),
            iconName: "shippingbox.fill",
            coverPath: "",
            minecraftVersion: versionId,
            gameDirectory: gameDir,
            javaPath: "",
            memoryMb: SettingsStore.memoryMb,
            memoryPolicy: settings.memoryPolicy,
            jvmProfile: settings.jvmProfile,
            graphicsProfile: settings.graphicsProfile,
            graphicsManualOverrides: [:],
            loader: loader.flatMap(LoaderKind.init(rawValue:)),
            loaderVersion: loaderVersion,
            jvmArguments: settings.jvmArguments,
            customJvmArguments: settings.jvmArguments,
            preLaunchBehavior: settings.installMissingFilesBeforeLaunch ? "Install missing files" : "Launch directly",
            group: "Local",
            isFavorite: false,
            lastLaunchedAt: nil,
            totalPlaySeconds: nil,
            status: versionJson && clientJar ? .ready : .notInstalled,
            baseMinecraftVersion: minecraftVersion
        )
    }

    private func displayNameFromDirectory() -> String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        let directoryName = URL(fileURLWithPath: gameDir, isDirectory: true).lastPathComponent
        guard !directoryName.isEmpty, directoryName != versionId else {
            return "Minecraft \(versionId)"
        }

        let words = directoryName
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map(String.init)
        guard !words.isEmpty else {
            return "Minecraft \(versionId)"
        }
        return words
            .map { word in
                word.contains(".") || word.allSatisfy(\.isNumber)
                    ? word
                    : word.capitalized
            }
            .joined(separator: " ")
    }

    private func uniqueName(_ baseName: String, existingNames: Set<String>) -> String {
        guard existingNames.contains(baseName) else { return baseName }
        var index = 2
        while existingNames.contains("\(baseName) \(index)") {
            index += 1
        }
        return "\(baseName) \(index)"
    }
}
