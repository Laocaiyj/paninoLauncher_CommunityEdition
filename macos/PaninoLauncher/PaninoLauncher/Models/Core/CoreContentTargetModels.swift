import Foundation

struct CoreContentTargetInstance: Codable, Equatable, Sendable {
    let instanceId: String?
    let name: String
    let gameDir: String
    let minecraftVersion: String
    let loader: String?
}

struct CoreContentResolveTargetsRequest: Codable, Equatable, Sendable {
    let projectType: String
    let projectTitle: String
    let releaseId: String?
    let targetSubdir: String
    let gameVersions: [String]
    let loaders: [String]
    let instances: [CoreContentTargetInstance]
}

struct CoreContentTargetCandidate: Decodable, Equatable, Identifiable, Sendable {
    let instanceId: String?
    let name: String
    let gameDir: String
    let minecraftVersion: String
    let loader: String?
    let score: Int
    let reasons: [String]
    let blockedReasons: [String]
    let recommended: Bool

    var id: String {
        [instanceId, gameDir, name].compactMap { $0 }.joined(separator: "|")
    }
}

struct CoreContentResolveTargetsResponse: Decodable, Equatable, Sendable {
    let candidates: [CoreContentTargetCandidate]
    let recommended: CoreContentTargetCandidate?
    let blockedReasons: [String]
}
