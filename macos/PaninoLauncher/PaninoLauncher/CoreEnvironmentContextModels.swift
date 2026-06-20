import Foundation

struct CoreEnvironmentContext: Codable, Equatable, Sendable {
    let gameDir: String?
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let configuredMemoryMb: Int?
    let memoryPolicy: String?
    let jvmProfile: String?
    let graphicsProfile: String?
    let graphicsHardwareTier: String?
    let displayScale: Double?
    let displayWidth: Int?
    let displayHeight: Int?
    let refreshRate: Int?
    let isBuiltinDisplay: Bool?
    let shaderEnabled: Bool?
    let resourcePackScale: String?
}
