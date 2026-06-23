import Foundation

@MainActor
extension TaskCenterStore {
    func applyTaowa(event: CoreEvent?) {
        guard let record = TaskCenterTaowaRecordAdapter.record(from: event) else { return }
        upsertLocal(
            id: record.id,
            kind: record.kind,
            name: record.name,
            version: record.version,
            gameDir: record.gameDir,
            state: record.state,
            progress: record.progress,
            currentFile: record.currentFile,
            errorCode: record.errorCode,
            errorDetail: record.errorDetail,
            diagnostic: record.diagnostic,
            diagnostics: record.diagnostics,
            message: record.message
        )
    }
}

private enum TaskCenterTaowaRecordAdapter {
    static func record(from event: CoreEvent?) -> TaowaTaskRecord? {
        guard let event,
              event.eventType.hasPrefix("taowa.session."),
              let session = event.payload?.session
        else { return nil }

        let primaryDiagnostic = event.payload?.diagnostic ?? session.diagnostics.first
        let state = TaskCenterRecordNormalizer.taowaRecordState(
            eventType: event.eventType,
            sessionStatus: session.status
        )

        return TaowaTaskRecord(
            id: "taowa:\(session.sessionId)",
            kind: "taowa-tunnel",
            name: "Taowa Tunnel",
            version: session.remoteAddress,
            gameDir: session.gameDir,
            state: state,
            progress: state.isActive ? 0.66 : 1,
            currentFile: "frpc \(session.localPort) -> \(session.remoteAddress)",
            errorCode: state.needsAttention ? primaryDiagnostic?.code : nil,
            errorDetail: primaryDiagnostic?.developerDetail,
            diagnostic: primaryDiagnostic,
            diagnostics: diagnostics(for: event, session: session, primary: primaryDiagnostic),
            message: message(for: state, event: event, session: session, primary: primaryDiagnostic)
        )
    }

    private static func diagnostics(
        for event: CoreEvent,
        session: CoreTaowaSession,
        primary: CoreDiagnostic?
    ) -> [CoreDiagnostic]? {
        if let diagnostics = event.payload?.diagnostics, !diagnostics.isEmpty {
            return diagnostics
        }
        if !session.diagnostics.isEmpty {
            return session.diagnostics
        }
        return primary.map { [$0] }
    }

    private static func message(
        for state: TaskRecordState,
        event: CoreEvent,
        session: CoreTaowaSession,
        primary: CoreDiagnostic?
    ) -> String {
        switch state {
        case .running:
            return "Taowa tunnel running at \(session.remoteAddress)."
        case .succeeded:
            return "Taowa tunnel stopped for \(session.remoteAddress)."
        case .failed, .interrupted:
            return primary?.userSummary ?? event.message
        case .queued, .cancelled:
            return event.message
        }
    }
}

private struct TaowaTaskRecord {
    let id: String
    let kind: String
    let name: String
    let version: String
    let gameDir: String?
    let state: TaskRecordState
    let progress: Double
    let currentFile: String
    let errorCode: String?
    let errorDetail: String?
    let diagnostic: CoreDiagnostic?
    let diagnostics: [CoreDiagnostic]?
    let message: String
}
