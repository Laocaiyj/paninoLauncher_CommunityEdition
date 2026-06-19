import Foundation

struct CoreNetworkEffectiveConfiguration: Codable, Equatable, Sendable {
    let sourceProfile: String
    let officialFallback: Bool
    let metadataRetryCount: Int
    let proxy: CoreNetworkProxyConfiguration
    let endpoints: [CoreNetworkSourceEndpointConfiguration]
}

struct CoreNetworkProxyConfiguration: Codable, Equatable, Sendable {
    let configured: Bool
    let value: String?
    let keys: [String]
}

struct CoreNetworkSourceEndpointConfiguration: Codable, Equatable, Sendable {
    let envVar: String
    let officialBase: String
    let configured: Bool
    let effectiveBases: [String]
}

struct CoreNetworkSourceTestResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let generatedAt: String
    let results: [CoreNetworkSourceTestResult]
}

struct CoreNetworkSourceTestResult: Codable, Equatable, Identifiable, Sendable {
    let endpoint: String
    let url: String
    let candidateCount: Int
    let selectedUrl: String?
    let selectedIndex: Int?
    let usedFallback: Bool
    let ok: Bool
    let status: Int?
    let latencyMs: Int?
    let error: String?
    let attempts: [CoreNetworkSourceTestAttempt]

    var id: String { endpoint }

    var statusText: String {
        if ok {
            let fallback = usedFallback ? " fallback" : ""
            let latency = latencyMs.map { " \($0) ms" } ?? ""
            return "OK\(fallback)\(latency)"
        }
        return error ?? "Failed"
    }
}

struct CoreNetworkSourceTestAttempt: Codable, Equatable, Sendable {
    let url: String
    let status: Int?
    let latencyMs: Int
    let ok: Bool
    let error: String?
}

struct CoreNetworkSpeedTestRequest: Encodable, Equatable, Sendable {
    let categories: [String]
    let urls: [String]
    let sampleBytes: Int64?

    static let settingsDefault = CoreNetworkSpeedTestRequest(
        categories: ["mojang-asset", "mojang-library", "client-jar", "fabric-metadata"],
        urls: [],
        sampleBytes: 4 * 1024 * 1024
    )
}

struct CoreNetworkSpeedTestResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let generatedAt: String
    let sampleBytes: Int64
    let results: [CoreNetworkSpeedTestResult]

    var fastestResult: CoreNetworkSpeedTestResult? {
        results.filter(\.ok).max { $0.bytesPerSecond < $1.bytesPerSecond }
    }
}

struct CoreNetworkSpeedTestResult: Codable, Equatable, Identifiable, Sendable {
    let endpoint: String
    let candidateUrl: String
    let host: String
    let status: Int?
    let bytes: Int64
    let elapsedMs: Int
    let bytesPerSecond: Int64
    let rangeSupported: Bool
    let usedProxy: Bool
    let error: String?
    let ok: Bool

    var id: String { endpoint + candidateUrl }

    var statusText: String {
        if ok {
            return "\(formattedBytes(bytesPerSecond))/s" + (rangeSupported ? " · Range" : " · single")
        }
        return error ?? "Failed"
    }
}
