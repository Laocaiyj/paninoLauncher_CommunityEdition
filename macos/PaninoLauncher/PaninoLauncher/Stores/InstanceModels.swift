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

enum InstanceIconBackdropStyle: String, Codable, CaseIterable, Identifiable {
    case automatic
    case none
    case plate
    case glass

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

struct GameInstance: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var iconName: String
    var coverPath: String
    var coverColorHex: String
    var coverFocusX: Double
    var coverFocusY: Double
    var coverBlur: Double
    var coverDim: Double
    var iconBackdropStyle: InstanceIconBackdropStyle
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
        coverFocusX: Double = 0.5,
        coverFocusY: Double = 0.5,
        coverBlur: Double = 0,
        coverDim: Double = 0.28,
        iconBackdropStyle: InstanceIconBackdropStyle = .automatic,
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
        self.coverFocusX = Self.clampedUnit(coverFocusX)
        self.coverFocusY = Self.clampedUnit(coverFocusY)
        self.coverBlur = Self.clampedUnit(coverBlur)
        self.coverDim = Self.clampedUnit(coverDim)
        self.iconBackdropStyle = iconBackdropStyle
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
        case coverFocusX
        case coverFocusY
        case coverBlur
        case coverDim
        case iconBackdropStyle
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
        coverFocusX = Self.clampedUnit(try container.decodeIfPresent(Double.self, forKey: .coverFocusX) ?? 0.5)
        coverFocusY = Self.clampedUnit(try container.decodeIfPresent(Double.self, forKey: .coverFocusY) ?? 0.5)
        coverBlur = Self.clampedUnit(try container.decodeIfPresent(Double.self, forKey: .coverBlur) ?? 0)
        coverDim = Self.clampedUnit(try container.decodeIfPresent(Double.self, forKey: .coverDim) ?? 0.28)
        iconBackdropStyle = try container.decodeIfPresent(InstanceIconBackdropStyle.self, forKey: .iconBackdropStyle) ?? .automatic
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

    static func clampedUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
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
