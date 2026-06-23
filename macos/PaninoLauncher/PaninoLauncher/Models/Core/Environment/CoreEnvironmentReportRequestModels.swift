import Foundation

struct CoreEnvironmentReportRequest: Equatable, Sendable {
    let gameDir: String?
    let version: String?
    let loader: String?
    let loaderVersion: String?
    let memoryMb: Int?

    let memoryPolicy: String?
    let jvmProfile: String?
    let customMemoryMb: Int?
    let customJvmArgs: String?
    let modCount: Int?
    let resourcePackCount: Int?
    let resourcePackScale: String?
    let shaderPackCount: Int?
    let graphicsProfile: String?
    let graphicsHardwareTier: String?
    let displayScale: Double?
    let displayWidth: Int?
    let displayHeight: Int?
    let refreshRate: Int?
    let isBuiltinDisplay: Bool?
    let shaderEnabled: Bool?

    init(
        gameDir: String?,
        version: String?,
        loader: String?,
        loaderVersion: String?,
        memoryMb: Int?,
        memoryPolicy: String? = nil,
        jvmProfile: String? = nil,
        customMemoryMb: Int? = nil,
        customJvmArgs: String? = nil,
        modCount: Int? = nil,
        resourcePackCount: Int? = nil,
        resourcePackScale: String? = nil,
        shaderPackCount: Int? = nil,
        graphicsProfile: String? = nil,
        graphicsHardwareTier: String? = nil,
        displayScale: Double? = nil,
        displayWidth: Int? = nil,
        displayHeight: Int? = nil,
        refreshRate: Int? = nil,
        isBuiltinDisplay: Bool? = nil,
        shaderEnabled: Bool? = nil
    ) {
        self.gameDir = gameDir
        self.version = version
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.memoryMb = memoryMb
        self.memoryPolicy = memoryPolicy
        self.jvmProfile = jvmProfile
        self.customMemoryMb = customMemoryMb
        self.customJvmArgs = customJvmArgs
        self.modCount = modCount
        self.resourcePackCount = resourcePackCount
        self.resourcePackScale = resourcePackScale
        self.shaderPackCount = shaderPackCount
        self.graphicsProfile = graphicsProfile
        self.graphicsHardwareTier = graphicsHardwareTier
        self.displayScale = displayScale
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.refreshRate = refreshRate
        self.isBuiltinDisplay = isBuiltinDisplay
        self.shaderEnabled = shaderEnabled
    }
}
