import Foundation

enum TaskRetrySupport {
    static func targetDescription(for record: TaskRecord, language: AppLanguage) -> String {
        let kind = record.kind.lowercased()
        if kind == "runtime.install" {
            return localizedString(language, english: "Retry Java download", chinese: "重试 Java 下载", italian: "Riprova download Java", french: "Réessayer Java", spanish: "Reintentar Java")
        }
        if kind.contains("launch") {
            return localizedString(language, english: "Retry launch", chinese: "重新启动", italian: "Riprova avvio", french: "Relancer", spanish: "Reintentar inicio")
        }
        if kind.contains("install") || kind.contains("download") {
            return localizedString(language, english: "Retry install/download", chinese: "重试安装/下载", italian: "Riprova installazione/download", french: "Réessayer installation/téléchargement", spanish: "Reintentar instalación/descarga")
        }
        return localizedString(language, english: "Retry task", chinese: "重试任务", italian: "Riprova attività", french: "Réessayer la tâche", spanish: "Reintentar tarea")
    }

    static func canRetryAutomatically(_ record: TaskRecord) -> Bool {
        let kind = record.kind.lowercased()
        guard record.state.isActive || record.state.needsAttention else { return false }
        guard !kind.contains("content") else { return false }
        return kind == "runtime.install" || kind.contains("install") || kind.contains("download") || kind.contains("launch") || kind.contains("log")
    }

    static func installRetryComponents(from record: TaskRecord) -> (loader: LoaderKind?, shaderLoader: String?) {
        let loaderValue = record.requestedLoader ?? detailValue("requestedLoader", in: record.errorDetail)
        let shaderValue = record.requestedShaderLoader ?? detailValue("requestedShaderLoader", in: record.errorDetail)
        return (
            loader: loaderValue.flatMap(loaderKind),
            shaderLoader: normalizedRetryComponent(shaderValue)
        )
    }

    static func javaFeatureVersion(from record: TaskRecord) -> Int? {
        if let major = javaMajorVersion(from: record.version) {
            return major
        }
        if let major = javaMajorVersion(from: record.name) {
            return major
        }
        return nil
    }

    static func diagnosticActionTitle(for record: TaskRecord, canRetryAutomatically: Bool) -> String? {
        guard let diagnostic = record.diagnostic ?? record.diagnostics?.first else { return nil }
        if diagnostic.action.kind == "retry", canRetryAutomatically {
            return nil
        }
        return diagnostic.actionLabel
    }

    static func diagnosticActionSystemImage(for record: TaskRecord) -> String {
        switch (record.diagnostic ?? record.diagnostics?.first)?.action.kind {
        case "installJava":
            return "cup.and.saucer"
        case "switchLoader", "switchVersion":
            return "slider.horizontal.3"
        case "configureApiKey":
            return "key"
        case "clearCache":
            return "trash"
        case "openFolder", "manualInstall":
            return "folder"
        case "configureTaowaFrp", "editFrpProfile":
            return "server.rack"
        case "openFrpcLog":
            return "terminal"
        case "lowerMemory":
            return "memorychip"
        case "applyGraphicsRecommendation":
            return "display"
        case "retry":
            return "arrow.clockwise"
        default:
            return "stethoscope"
        }
    }

    private static func loaderKind(_ value: String) -> LoaderKind? {
        let normalized = normalizedRetryComponent(value)?.lowercased()
        return LoaderKind.allCases.first { kind in
            kind.rawValue.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "") == normalized
        }
    }

    private static func detailValue(_ key: String, in detail: String?) -> String? {
        guard let detail else { return nil }
        let prefix = "\(key)="
        return detail
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private static func normalizedRetryComponent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "-" || trimmed.lowercased() == "none" || trimmed.lowercased() == "vanilla" {
            return nil
        }
        return trimmed
    }
}
