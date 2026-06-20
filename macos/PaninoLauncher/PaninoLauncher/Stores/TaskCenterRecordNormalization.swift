import Foundation

enum TaskCenterRecordNormalizer {
    static func normalizedErrorCode(kind: String, errorCode: String?) -> String? {
        guard let errorCode else { return nil }
        if kind == "install", errorCode == "process_launch_failed" {
            return "install_failed"
        }
        if kind == "content-install", errorCode == "process_launch_failed" {
            return "content_install_failed"
        }
        return errorCode
    }

    static func primaryDiagnostic(snapshot: TaskSnapshot) -> CoreDiagnostic? {
        snapshot.diagnostic ?? snapshot.diagnostics.first
    }

    static func diagnostics(snapshot: TaskSnapshot, primary: CoreDiagnostic?) -> [CoreDiagnostic]? {
        let values = snapshot.diagnostics.isEmpty ? primary.map { [$0] } ?? [] : snapshot.diagnostics
        return values.isEmpty ? nil : values
    }

    static func localDiagnostic(
        kind: String,
        gameDir: String?,
        state: TaskRecordState,
        errorCode: String?,
        errorDetail: String?,
        message: String
    ) -> CoreDiagnostic? {
        guard state.needsAttention, let errorCode, !errorCode.isEmpty else { return nil }
        let action = localDiagnosticAction(errorCode: errorCode)
        let evidence = gameDir.map { [CoreDiagnosticEvidence(key: "gameDir", value: $0, redacted: false)] } ?? []
        return CoreDiagnostic(
            code: errorCode,
            phase: localDiagnosticPhase(kind: kind, errorCode: errorCode),
            severity: "error",
            title: "Local task failed",
            message: message,
            cause: errorDetail ?? message,
            action: action,
            retryable: action.kind == "retry",
            userVisible: true,
            source: "swift",
            taskId: nil,
            planId: nil,
            packageId: nil,
            filePath: nil,
            urlHost: nil,
            evidence: evidence,
            developerDetail: errorDetail
        )
    }

    static func taowaRecordState(eventType: String, sessionStatus: String) -> TaskRecordState {
        if eventType == "taowa.session.failed" || sessionStatus == "failed" {
            return .failed
        }
        if eventType == "taowa.session.stopped" || sessionStatus == "stopped" {
            return .succeeded
        }
        if ["prepared", "startingFrpc", "running"].contains(sessionStatus) {
            return .running
        }
        return .running
    }

    static func normalizedMessage(kind: String, message: String?, errorCode: String?) -> String? {
        if kind == "runtime.install" {
            if let errorCode, !errorCode.isEmpty {
                return message ?? "Java Runtime install failed. Open logs for the Core error detail, then retry."
            }
            if let message, !message.isEmpty {
                return message
            }
            return nil
        }
        if kind == "install", errorCode == "install_failed" {
            return "Install failed before Minecraft was ready. Open logs for the Core error detail, then retry."
        }
        if kind == "content-install", errorCode == "content_install_failed" {
            return "Content install failed. Open logs for the Core error detail, then retry."
        }
        return message
    }

    static func normalizedRecord(_ record: TaskRecord) -> TaskRecord {
        var next = record
        let errorCode = normalizedErrorCode(kind: record.kind, errorCode: record.errorCode)
        next.errorCode = errorCode
        next.message = record.diagnostic?.userSummary ?? normalizedMessage(kind: record.kind, message: record.message, errorCode: errorCode) ?? record.message
        if next.diagnostics == nil, let diagnostic = next.diagnostic {
            next.diagnostics = [diagnostic]
        }
        if record.kind == "runtime.install" {
            next.name = displayName(kind: record.kind, version: record.version)
        }
        return next
    }

    static func displayName(kind: String, version: String) -> String {
        if kind == "runtime.install" {
            if let major = javaMajorVersion(from: version) {
                return "Java Runtime \(major)"
            }
            return version.isEmpty ? "Java Runtime" : "Java Runtime \(version)"
        }
        return "\(kind.capitalized) \(version)"
    }

    static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return fractional.date(from: value) ?? plain.date(from: value)
    }

    private static func localDiagnosticPhase(kind: String, errorCode: String) -> String {
        let source = "\(kind) \(errorCode)".lowercased()
        if source.contains("cache") {
            return "diagnostic"
        }
        if source.contains("archive") || source.contains("backup") || source.contains("source") {
            return "write"
        }
        return "diagnostic"
    }

    private static func localDiagnosticAction(errorCode: String) -> CoreDiagnosticAction {
        switch errorCode {
        case "cache_cleanup_failed":
            return CoreDiagnosticAction(kind: "clearCache", label: "Clear cache")
        case "missing_source", "archive_failed", "preflight_blocked":
            return CoreDiagnosticAction(kind: "openDiagnostics", label: "Open diagnostics")
        default:
            return CoreDiagnosticAction(kind: "openDiagnostics", label: "Open diagnostics")
        }
    }
}
