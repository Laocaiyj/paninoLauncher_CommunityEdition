import Foundation

struct CoreLoaderInstallPreflightRequest: Encodable, Equatable, Sendable {
    let version: String
    let gameDir: String?
    let loader: String?
    let loaderVersion: String?
    let shaderLoader: String?
    let shaderVersion: String?
    let instanceName: String?
}

struct CoreLoaderInstallPreflightResponse: Decodable, Equatable, Sendable {
    let status: String
    let minecraftVersion: String
    let loader: String?
    let loaderVersion: String?
    let loaderProfileId: String?
    let shaderLoader: String?
    let shaderVersion: String?
    let shaderResolvedLoader: String?
    let shaderFallbackFrom: String?
    let shaderFallbackTo: String?
    let installerProbeStatus: String?
    let shaderProjects: [String]
    let requiredDependencies: [String]
    let javaRuntime: CoreJavaRuntimeResolveResponse?
    let warnings: [String]
    let blockedReasons: [String]
    let typedPlan: CoreTypedInstallPlan
    let diagnostics: CoreLoaderInstallPreflightDiagnostics
    let diagnostic: CoreDiagnostic?
    let structuredDiagnostics: [CoreDiagnostic]?

    var isBlocked: Bool {
        status == "blocked" || !blockedReasons.isEmpty
    }

    var displaySummary: String {
        if isBlocked {
            if let diagnostic, !diagnostic.userSummary.isEmpty {
                return diagnostic.userSummary
            }
            if let structured = structuredDiagnostics?.first, !structured.userSummary.isEmpty {
                return structured.userSummary
            }
            return blockedReasons.first ?? "Install is blocked."
        }
        if status == "warning" {
            return warnings.first ?? "Install can continue with warnings."
        }
        return "Install can continue."
    }
}

struct CoreLoaderInstallPreflightDiagnostics: Decodable, Equatable, Sendable {
    let loaderSources: [CoreLoaderMetadataSourceResult]
    let loaderProfileUrl: String?
    let installerUrl: String?
    let installerProbeStatus: String?
    let shaderProjects: [String]
}

struct CoreLoaderMetadataSourceResult: Decodable, Equatable, Sendable {
    let source: String
    let ok: Bool
    let versions: [LoaderMetadata]
    let versionCount: Int
    let selectedVersion: String?
    let error: String?
    let latencyMs: Int
}

struct CoreInstallPreflightBlockedError: Decodable, Equatable, Sendable {
    let error: String
    let diagnostic: CoreDiagnostic?
    let structuredDiagnostics: [CoreDiagnostic]?
    let blockedReasons: [String]?
    let preflight: CoreLoaderInstallPreflightResponse?
}
