import Foundation

struct CoreCompatibilityTarget: Codable, Equatable, Sendable {
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let shaderLoader: String?
    let gameDir: String?
    let javaMajor: Int?
    let requiredJavaMajor: Int?
    let javaArch: String?
    let systemArch: String?
}

struct CoreCompatibilityPackageInput: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let source: String?
    let kind: String
    let minecraftVersions: [String]
    let loaders: [String]
    let requiredDependencies: [String]
    let optionalDependencies: [String]
    let present: Bool
    let metadataComplete: Bool
    let javaMajor: Int?
}

struct CoreCompatibilityEvaluateRequest: Codable, Equatable, Sendable {
    let target: CoreCompatibilityTarget
    let packages: [CoreCompatibilityPackageInput]
    let installedPackageIds: [String]
    let missingRequiredDependencies: [String]
    let missingOptionalDependencies: [String]
    let blockedReasons: [String]
    let warnings: [String]

    init(
        target: CoreCompatibilityTarget,
        packages: [CoreCompatibilityPackageInput] = [],
        installedPackageIds: [String] = [],
        missingRequiredDependencies: [String] = [],
        missingOptionalDependencies: [String] = [],
        blockedReasons: [String] = [],
        warnings: [String] = []
    ) {
        self.target = target
        self.packages = packages
        self.installedPackageIds = installedPackageIds
        self.missingRequiredDependencies = missingRequiredDependencies
        self.missingOptionalDependencies = missingOptionalDependencies
        self.blockedReasons = blockedReasons
        self.warnings = warnings
    }
}

struct CoreCompatibilityPackageReport: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let status: String
    let diagnostics: [CoreDiagnostic]
    let blockedReasons: [String]
    let warnings: [String]
    let actions: [CoreDiagnosticAction]
}

struct CoreCompatibilityReport: Codable, Equatable, Sendable {
    let status: String
    let target: CoreCompatibilityTarget
    let packageReports: [CoreCompatibilityPackageReport]
    let globalDiagnostics: [CoreDiagnostic]
    let blockedReasons: [String]
    let warnings: [String]
    let actions: [CoreDiagnosticAction]
    let summary: String

    var allDiagnostics: [CoreDiagnostic] {
        globalDiagnostics + packageReports.flatMap(\.diagnostics)
    }

    var primaryDiagnostic: CoreDiagnostic? {
        allDiagnostics.first
    }
}

struct CoreCompatibilityExplanation: Codable, Equatable, Sendable {
    let status: String
    let summary: String
    let reasons: [String]
    let actions: [String]
    let report: CoreCompatibilityReport
}
