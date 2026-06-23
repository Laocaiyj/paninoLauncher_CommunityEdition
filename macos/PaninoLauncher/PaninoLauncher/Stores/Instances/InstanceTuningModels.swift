import Foundation

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
