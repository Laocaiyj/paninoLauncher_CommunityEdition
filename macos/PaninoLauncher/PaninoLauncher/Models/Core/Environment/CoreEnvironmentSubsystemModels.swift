import Foundation

struct CoreEnvironmentSystem: Codable, Equatable, Sendable {
    let os: String
    let architecture: String
    let cpuCapabilities: Int
    let memoryBytes: Int64?
    let hardwareProfile: CoreHardwareProfile?
    let fileDescriptorLimit: Int?
}

struct CoreHardwareProfile: Codable, Equatable, Sendable {
    let chipName: String?
    let chipTier: String
    let memoryBytes: Int64?
    let memoryTier: String
}

struct CoreEnvironmentJava: Codable, Equatable, Sendable {
    let status: JavaRuntimeStatus
    let architecture: String
    let requiredMajorVersion: Int?
    let installedMajorVersion: Int?
    let architectureMatchesSystem: Bool?
    let conclusion: String
    let actions: [String]
}

struct CoreEnvironmentDirectories: Codable, Equatable, Sendable {
    let gameDir: String?
    let status: String
    let writable: Bool
    let availableDiskBytes: Int64?
    let writeSampleBytes: Int
    let writeElapsedMs: Int?
    let writeBytesPerSecond: Int64
    let error: String?
    let cache: CoreEnvironmentDirectoryCheck?
    let staging: CoreEnvironmentDirectoryCheck?
    let checks: [CoreEnvironmentDirectoryCheck]?
    let actions: [String]
}

struct CoreEnvironmentDirectoryCheck: Codable, Equatable, Sendable {
    let id: String
    let path: String
    let status: String
    let writable: Bool
    let error: String?
    let actions: [String]
}

struct CoreEnvironmentMemory: Codable, Equatable, Sendable {
    let systemBytes: Int64?
    let configuredMb: Int?
    let recommendedMb: Int
    let conclusion: String
    let actions: [String]
}

struct CoreEnvironmentNetwork: Codable, Equatable, Sendable {
    let effective: CoreNetworkEffectiveConfiguration
    let speedTestEndpoint: String
    let sourceTest: CoreNetworkSourceTestResponse?
}

struct CoreEnvironmentCompatibility: Codable, Equatable, Sendable {
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let conclusion: String
    let actions: [String]
}
