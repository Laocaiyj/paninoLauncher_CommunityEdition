import Foundation

struct CoreConfigurationCapabilities: Decodable, Equatable, Sendable {
    let canLaunch: Bool
    let canManageMods: Bool
    let canManageResourcePacks: Bool
    let canManageShaderPacks: Bool
    let canInstallLoader: Bool
    let canExportModpack: Bool
    let canBackupSaves: Bool
    let canRepair: Bool
    let reasons: [String]
}

struct CoreLoaderCompatibilityEntry: Decodable, Equatable, Sendable {
    let loader: String
    let available: Bool
    let recommendedVersion: String?
    let versions: [String]
    let reason: String?
    let experimental: Bool
}

struct CoreLoaderCompatibilityResponse: Decodable, Equatable, Sendable {
    let minecraftVersion: String
    let options: [CoreLoaderCompatibilityEntry]
}

struct CoreVersionSwitchPreflightRequest: Encodable, Equatable, Sendable {
    let configuration: CoreGameConfigurationRequest
    let targetMinecraftVersion: String
}

struct CoreVersionSwitchPreflightResponse: Decodable, Equatable, Sendable {
    let allowed: Bool
    let recommendedAction: String
    let warnings: [String]
    let blockingReasons: [String]
    let capabilities: CoreConfigurationCapabilities
}
