import Foundation

extension GameInstance {
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
}
