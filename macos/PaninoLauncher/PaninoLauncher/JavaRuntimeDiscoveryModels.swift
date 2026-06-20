import Foundation

struct JavaRuntimeCandidate: Decodable, Identifiable, Equatable, Sendable {
    let path: String
    let isAvailable: Bool
    let versionSummary: String
    let source: String
    let canDelete: Bool?
    let deleteTarget: String?

    var id: String { path }

    var displayText: String {
        cleanVersionSummary.isEmpty ? path : cleanVersionSummary
    }

    var hasMeaningfulSummary: Bool {
        !cleanVersionSummary.isEmpty
    }

    var pathDetailText: String {
        path.isEmpty ? "java" : path
    }

    var supportsDeletion: Bool {
        canDelete == true && !(deleteTarget?.isEmpty ?? true)
    }

    private var cleanVersionSummary: String {
        let trimmed = versionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.localizedCaseInsensitiveCompare("Property settings:") != .orderedSame else {
            return ""
        }
        return trimmed
    }
}

struct JavaRuntimeStatus: Codable, Equatable, Sendable {
    let path: String
    let isAvailable: Bool
    let versionSummary: String
    let version: String?
    let majorVersion: Int?
    let vendor: String?
    let architecture: String?
    let executablePermission: Bool?
    let rawSummary: String?

    init(
        path: String,
        isAvailable: Bool,
        versionSummary: String,
        version: String? = nil,
        majorVersion: Int? = nil,
        vendor: String? = nil,
        architecture: String? = nil,
        executablePermission: Bool? = nil,
        rawSummary: String? = nil
    ) {
        self.path = path
        self.isAvailable = isAvailable
        self.versionSummary = versionSummary
        self.version = version
        self.majorVersion = majorVersion
        self.vendor = vendor
        self.architecture = architecture
        self.executablePermission = executablePermission
        self.rawSummary = rawSummary
    }

    var displayText: String {
        if isAvailable {
            return versionSummary.isEmpty ? "Java available" : versionSummary
        }
        return versionSummary.isEmpty ? "Java unavailable" : versionSummary
    }
}
