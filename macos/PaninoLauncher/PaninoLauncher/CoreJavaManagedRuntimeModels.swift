import Foundation

struct CoreJavaManagedResponse: Codable, Equatable, Sendable {
    let runtimes: [CoreJavaManagedRuntime]
    let root: String
}

struct CoreJavaManagedRuntime: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let vendor: String
    let provider: String
    let featureVersion: Int
    let version: String
    let os: String
    let arch: String
    let imageType: String
    let javaHome: String
    let javaExecutable: String
    let sourceUrl: String
    let sha256: String?
    let installedAt: Date
    let lastVerifiedAt: Date?
    let diskUsageBytes: Int64?
    let usedByInstanceCount: Int

    var displayName: String {
        "Java \(featureVersion)"
    }

    var detailText: String {
        [
            vendor.capitalized,
            osDisplayName,
            archDisplayName,
            imageType.uppercased(),
            diskUsageBytes.map { formattedBytes($0) }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var osDisplayName: String {
        os == "mac" ? "macOS" : os
    }

    private var archDisplayName: String {
        switch arch {
        case "aarch64":
            return "ARM64"
        case "x64":
            return "x64"
        default:
            return arch
        }
    }
}
