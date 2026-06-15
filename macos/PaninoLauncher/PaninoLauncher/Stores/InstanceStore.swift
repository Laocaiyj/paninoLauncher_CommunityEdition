import Foundation
import SwiftUI

enum InstanceStatus: String, Codable, CaseIterable, Identifiable {
    case notInstalled
    case ready
    case installing
    case running
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notInstalled:
            return "Needs Install"
        case .ready:
            return "Ready"
        case .installing:
            return "Installing"
        case .running:
            return "Running"
        case .failed:
            return "Failed"
        }
    }
}

enum LaunchHistoryState: String, Codable, CaseIterable, Identifiable {
    case running
    case succeeded
    case failed
    case cancelled

    var id: String { rawValue }
}

enum InstanceMemoryPolicy: String, Codable, CaseIterable, Identifiable {
    case auto
    case custom

    var id: String { rawValue }
}

enum InstanceJvmProfile: String, Codable, CaseIterable, Identifiable {
    case auto
    case largePack
    case lowMemory
    case batterySaver
    case experimentalZgc
    case custom

    var id: String { rawValue }
}

enum InstanceGraphicsProfile: String, Codable, CaseIterable, Identifiable {
    case clarity
    case balanced
    case performance
    case batterySaver
    case manual

    var id: String { rawValue }
}

struct JvmTuningSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var instanceId: UUID
    var recordedAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var state: LaunchHistoryState
    var memoryPolicy: InstanceMemoryPolicy
    var jvmProfile: InstanceJvmProfile
    var configuredMemoryMb: Int
    var customMemoryMb: Int?
    var customJvmArgs: [String]
    var finalXmsMb: Int?
    var finalXmxMb: Int?
    var finalGc: String?
    var finalJvmArgs: [String]
    var systemMemoryMb: Int?
    var packScale: String?
    var tuningSummary: String?
    var warningCodes: [String]
    var exitCode: Int?
    var heapOutOfMemory: Bool
    var nativeOutOfMemory: Bool
    var gcOverheadLimit: Bool
}

struct GraphicsTuningSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var instanceId: UUID
    var recordedAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var state: LaunchHistoryState
    var graphicsProfile: InstanceGraphicsProfile
    var effectiveProfile: String?
    var hardwareTier: String?
    var retinaPolicy: String?
    var currentOptions: [String: String]
    var recommendedOptions: [String: String]
    var patchChanges: [CoreOptionsPatchChange]
    var tuningSummary: String?
    var warningCodes: [String]
    var backupPath: String?
    var canRollback: Bool
    var quickExit: Bool
    var crashed: Bool
    var renderRelatedError: Bool
}

private struct GraphicsTuningDiagnostic: Codable {
    let tuning: CoreResolvedGraphicsTuning
}

struct GameInstance: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var iconName: String
    var coverPath: String
    var coverColorHex: String
    var minecraftVersion: String
    var baseMinecraftVersion: String?
    var gameDirectory: String
    var javaPath: String
    var memoryMb: Int
    var memoryPolicy: InstanceMemoryPolicy
    var jvmProfile: InstanceJvmProfile
    var graphicsProfile: InstanceGraphicsProfile
    var graphicsManualOverrides: [String: String]
    var customMemoryMb: Int?
    var loader: LoaderKind?
    var loaderVersion: String?
    var jvmArguments: String
    var customJvmArguments: String
    var preLaunchBehavior: String
    var group: String
    var isFavorite: Bool
    var lastLaunchedAt: Date?
    var totalPlaySeconds: TimeInterval?
    var status: InstanceStatus
    var lastLaunchDuration: TimeInterval?
    var lastLaunchState: LaunchHistoryState?
    var launchCount: Int
    var isHiddenFromRecent: Bool
    var lastJvmTuningSnapshot: JvmTuningSnapshot?
    var lastKnownGoodJvmTuning: JvmTuningSnapshot?
    var lastGraphicsTuningSnapshot: GraphicsTuningSnapshot?
    var lastKnownGoodGraphicsTuning: GraphicsTuningSnapshot?

    init(
        id: UUID,
        name: String,
        iconName: String,
        coverPath: String,
        coverColorHex: String = GameInstance.defaultCoverColorHex,
        minecraftVersion: String,
        gameDirectory: String,
        javaPath: String,
        memoryMb: Int,
        memoryPolicy: InstanceMemoryPolicy = .auto,
        jvmProfile: InstanceJvmProfile = .auto,
        graphicsProfile: InstanceGraphicsProfile = .balanced,
        graphicsManualOverrides: [String: String] = [:],
        customMemoryMb: Int? = nil,
        loader: LoaderKind?,
        loaderVersion: String?,
        jvmArguments: String,
        customJvmArguments: String? = nil,
        preLaunchBehavior: String,
        group: String,
        isFavorite: Bool,
        lastLaunchedAt: Date?,
        totalPlaySeconds: TimeInterval?,
        status: InstanceStatus,
        lastLaunchDuration: TimeInterval? = nil,
        lastLaunchState: LaunchHistoryState? = nil,
        launchCount: Int = 0,
        isHiddenFromRecent: Bool = false,
        lastJvmTuningSnapshot: JvmTuningSnapshot? = nil,
        lastKnownGoodJvmTuning: JvmTuningSnapshot? = nil,
        lastGraphicsTuningSnapshot: GraphicsTuningSnapshot? = nil,
        lastKnownGoodGraphicsTuning: GraphicsTuningSnapshot? = nil,
        baseMinecraftVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.coverPath = coverPath
        self.coverColorHex = coverColorHex
        self.minecraftVersion = minecraftVersion
        self.baseMinecraftVersion = baseMinecraftVersion
        self.gameDirectory = gameDirectory
        self.javaPath = javaPath
        self.memoryMb = memoryMb
        self.memoryPolicy = memoryPolicy
        self.jvmProfile = jvmProfile
        self.graphicsProfile = graphicsProfile
        self.graphicsManualOverrides = graphicsManualOverrides
        self.customMemoryMb = customMemoryMb
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.jvmArguments = jvmArguments
        self.customJvmArguments = customJvmArguments ?? jvmArguments
        self.preLaunchBehavior = preLaunchBehavior
        self.group = group
        self.isFavorite = isFavorite
        self.lastLaunchedAt = lastLaunchedAt
        self.totalPlaySeconds = totalPlaySeconds
        self.status = status
        self.lastLaunchDuration = lastLaunchDuration
        self.lastLaunchState = lastLaunchState
        self.launchCount = launchCount
        self.isHiddenFromRecent = isHiddenFromRecent
        self.lastJvmTuningSnapshot = lastJvmTuningSnapshot
        self.lastKnownGoodJvmTuning = lastKnownGoodJvmTuning
        self.lastGraphicsTuningSnapshot = lastGraphicsTuningSnapshot
        self.lastKnownGoodGraphicsTuning = lastKnownGoodGraphicsTuning
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconName
        case coverPath
        case coverColorHex
        case minecraftVersion
        case baseMinecraftVersion
        case gameDirectory
        case javaPath
        case memoryMb
        case memoryPolicy
        case jvmProfile
        case graphicsProfile
        case graphicsManualOverrides
        case customMemoryMb
        case loader
        case loaderVersion
        case jvmArguments
        case customJvmArguments
        case preLaunchBehavior
        case group
        case isFavorite
        case lastLaunchedAt
        case totalPlaySeconds
        case status
        case lastLaunchDuration
        case lastLaunchState
        case launchCount
        case isHiddenFromRecent
        case lastJvmTuningSnapshot
        case lastKnownGoodJvmTuning
        case lastGraphicsTuningSnapshot
        case lastKnownGoodGraphicsTuning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        coverPath = try container.decode(String.self, forKey: .coverPath)
        coverColorHex = try container.decodeIfPresent(String.self, forKey: .coverColorHex) ?? Self.defaultCoverColorHex
        minecraftVersion = try container.decode(String.self, forKey: .minecraftVersion)
        baseMinecraftVersion = try container.decodeIfPresent(String.self, forKey: .baseMinecraftVersion)
        gameDirectory = try container.decode(String.self, forKey: .gameDirectory)
        javaPath = try container.decode(String.self, forKey: .javaPath)
        memoryMb = try container.decode(Int.self, forKey: .memoryMb)
        let decodedMemoryPolicy = try container.decodeIfPresent(InstanceMemoryPolicy.self, forKey: .memoryPolicy)
        memoryPolicy = decodedMemoryPolicy ?? .custom
        loader = try container.decodeIfPresent(LoaderKind.self, forKey: .loader)
        loaderVersion = try container.decodeIfPresent(String.self, forKey: .loaderVersion)
        jvmArguments = try container.decode(String.self, forKey: .jvmArguments)
        customMemoryMb = try container.decodeIfPresent(Int.self, forKey: .customMemoryMb) ?? (memoryPolicy == .custom ? memoryMb : nil)
        customJvmArguments = try container.decodeIfPresent(String.self, forKey: .customJvmArguments) ?? jvmArguments
        if let decodedJvmProfile = try container.decodeIfPresent(InstanceJvmProfile.self, forKey: .jvmProfile) {
            jvmProfile = decodedJvmProfile
        } else {
            jvmProfile = jvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && memoryPolicy == .auto ? .auto : .custom
        }
        graphicsProfile = try container.decodeIfPresent(InstanceGraphicsProfile.self, forKey: .graphicsProfile) ?? .balanced
        graphicsManualOverrides = try container.decodeIfPresent([String: String].self, forKey: .graphicsManualOverrides) ?? [:]
        preLaunchBehavior = try container.decode(String.self, forKey: .preLaunchBehavior)
        group = try container.decode(String.self, forKey: .group)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        lastLaunchedAt = try container.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
        totalPlaySeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .totalPlaySeconds)
        status = try container.decode(InstanceStatus.self, forKey: .status)
        lastLaunchDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .lastLaunchDuration)
        lastLaunchState = try container.decodeIfPresent(LaunchHistoryState.self, forKey: .lastLaunchState)
        launchCount = try container.decodeIfPresent(Int.self, forKey: .launchCount) ?? (lastLaunchedAt == nil ? 0 : 1)
        isHiddenFromRecent = try container.decodeIfPresent(Bool.self, forKey: .isHiddenFromRecent) ?? false
        lastJvmTuningSnapshot = try container.decodeIfPresent(JvmTuningSnapshot.self, forKey: .lastJvmTuningSnapshot)
        lastKnownGoodJvmTuning = try container.decodeIfPresent(JvmTuningSnapshot.self, forKey: .lastKnownGoodJvmTuning)
        lastGraphicsTuningSnapshot = try container.decodeIfPresent(GraphicsTuningSnapshot.self, forKey: .lastGraphicsTuningSnapshot)
        lastKnownGoodGraphicsTuning = try container.decodeIfPresent(GraphicsTuningSnapshot.self, forKey: .lastKnownGoodGraphicsTuning)
    }
}

extension GameInstance {
    static let defaultCoverColorHex = "#ef4444"

    var resolvedIconName: String {
        iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "cube.fill" : iconName
    }

    var coverTintColor: Color {
        Color.paninoHex(coverColorHex, fallback: status.badgeStyle.color)
    }

    var contentMinecraftVersion: String {
        if let value = baseMinecraftVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return value
        }
        return Self.contentMinecraftVersion(from: minecraftVersion)
    }

    mutating func restoreAutomaticJvmTuning(defaultMemoryMb: Int = SettingsStore.memoryMb) {
        memoryPolicy = .auto
        jvmProfile = .auto
        customMemoryMb = nil
        memoryMb = defaultMemoryMb
        customJvmArguments = ""
        jvmArguments = ""
    }

    mutating func restoreAutomaticGraphicsTuning() {
        graphicsProfile = .balanced
        graphicsManualOverrides = [:]
    }

    mutating func applyJvmTuningSnapshot(_ snapshot: JvmTuningSnapshot) {
        memoryPolicy = snapshot.memoryPolicy
        jvmProfile = snapshot.jvmProfile
        memoryMb = snapshot.configuredMemoryMb
        customMemoryMb = snapshot.customMemoryMb
        customJvmArguments = snapshot.customJvmArgs.joined(separator: " ")
        jvmArguments = customJvmArguments
    }

    private static func contentMinecraftVersion(from rawValue: String) -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return rawValue }

        let lowercased = value.lowercased()
        for marker in ["-forge-", "-neoforge-", "-fabric-", "-quilt-"] {
            guard let range = lowercased.range(of: marker) else { continue }
            let prefix = String(value[..<range.lowerBound])
            if looksLikeMinecraftRelease(prefix) {
                return prefix
            }
        }

        let parts = value.split(separator: "-").map(String.init)
        guard !parts.isEmpty else { return value }
        for index in stride(from: parts.count - 1, through: 0, by: -1) {
            let candidate = parts[index...].joined(separator: "-")
            if looksLikeMinecraftRelease(candidate) {
                return candidate
            }
        }
        return value
    }

    private static func looksLikeMinecraftRelease(_ value: String) -> Bool {
        let mainPart = value.split(separator: "-").first.map(String.init) ?? value
        let numericParts = mainPart.split(separator: ".")
        guard numericParts.count >= 2 else { return false }
        return numericParts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber)
        }
    }
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
