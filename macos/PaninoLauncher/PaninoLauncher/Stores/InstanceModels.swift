import Foundation

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
