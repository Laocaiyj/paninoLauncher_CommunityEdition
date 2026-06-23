import Foundation

struct CoreResolvedGraphicsTuning: Codable, Equatable, Sendable {
    let requestedProfile: String
    let effectiveProfile: String
    let hardwareTier: String
    let retinaPolicy: String
    let currentOptions: [String: String]
    let recommendedOptions: [String: String]
    let optionsPatch: CoreOptionsPatch
    let summary: String
    let confidence: String?
    let evidence: [CorePerformanceEvidence]?
    let rollbackRef: String?
    let applyMode: String?
    let warnings: [CoreGraphicsTuningWarning]
    let actions: [CoreGraphicsTuningAction]
    let primaryAction: CoreGraphicsTuningAction?
    let backupPath: String?
    let canApply: Bool
    let canRollback: Bool
}

struct CoreGraphicsTuningRequest: Codable, Equatable, Sendable {
    let instanceId: String?
    let gameDir: String?
    let minecraftVersion: String?
    let loader: String?
    let hardwareTier: String?
    let displayScale: Double?
    let displayWidth: Int?
    let displayHeight: Int?
    let refreshRate: Int?
    let isBuiltinDisplay: Bool?
    let powerMode: String?
    let requestedProfile: String
    let shaderEnabled: Bool
    let resourcePackScale: String?
    let modCount: Int?
    let previousSnapshot: CoreResolvedGraphicsTuning?
    let manualOverrides: [String: String]
    let dryRun: Bool

    init(
        instanceId: String? = nil,
        gameDir: String?,
        minecraftVersion: String?,
        loader: String?,
        hardwareTier: String? = nil,
        displayScale: Double? = nil,
        displayWidth: Int? = nil,
        displayHeight: Int? = nil,
        refreshRate: Int? = nil,
        isBuiltinDisplay: Bool? = nil,
        powerMode: String? = nil,
        requestedProfile: String,
        shaderEnabled: Bool = false,
        resourcePackScale: String? = nil,
        modCount: Int? = nil,
        previousSnapshot: CoreResolvedGraphicsTuning? = nil,
        manualOverrides: [String: String] = [:],
        dryRun: Bool = true
    ) {
        self.instanceId = instanceId
        self.gameDir = gameDir
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.hardwareTier = hardwareTier
        self.displayScale = displayScale
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.refreshRate = refreshRate
        self.isBuiltinDisplay = isBuiltinDisplay
        self.powerMode = powerMode
        self.requestedProfile = requestedProfile
        self.shaderEnabled = shaderEnabled
        self.resourcePackScale = resourcePackScale
        self.modCount = modCount
        self.previousSnapshot = previousSnapshot
        self.manualOverrides = manualOverrides
        self.dryRun = dryRun
    }
}

struct CoreGraphicsTuningApplyResponse: Codable, Equatable, Sendable {
    let applied: Bool
    let backup: CoreOptionsBackup
    let tuning: CoreResolvedGraphicsTuning
}

struct CoreGraphicsTuningRollbackRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let backupPath: String?
}

struct CoreGraphicsTuningRollbackResponse: Codable, Equatable, Sendable {
    let rolledBack: Bool
    let restoredFrom: String
    let backup: CoreOptionsBackup
}

struct CoreGraphicsTuningWarning: Codable, Equatable, Sendable {
    let code: String
    let severity: String
    let message: String
    let action: String?
}

struct CoreGraphicsTuningAction: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let options: [String: String]
}

struct CoreOptionsPatch: Codable, Equatable, Sendable {
    let path: String?
    let changes: [CoreOptionsPatchChange]
}

struct CoreOptionsPatchChange: Codable, Equatable, Sendable {
    let key: String
    let oldValue: String?
    let newValue: String?
    let reason: String
    let status: String
}

struct CoreOptionsBackup: Codable, Equatable, Sendable {
    let sourcePath: String
    let stablePath: String?
    let timestampPath: String?
    let created: Bool
    let error: String?
}
