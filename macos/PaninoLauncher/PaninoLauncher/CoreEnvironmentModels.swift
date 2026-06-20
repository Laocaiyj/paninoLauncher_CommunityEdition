import Foundation

struct CoreEnvironmentReport: Codable, Equatable, Sendable {
    let ok: Bool
    let generatedAt: String
    let performanceSummary: CorePerformanceSummary?
    let context: CoreEnvironmentContext?
    let system: CoreEnvironmentSystem
    let java: CoreEnvironmentJava
    let javaResolution: CoreJavaRuntimeResolveResponse?
    let jvmTuning: CoreResolvedJvmTuning?
    let launchEffectiveJvmArgs: [String]?
    let graphicsTuning: CoreResolvedGraphicsTuning?
    let performancePackRecommendation: CorePerformancePackRecommendation?
    let runtimeFeedback: CoreRuntimeFeedback?
    let directories: CoreEnvironmentDirectories
    let memory: CoreEnvironmentMemory?
    let network: CoreEnvironmentNetwork
    let compatibility: CoreEnvironmentCompatibility?
}
