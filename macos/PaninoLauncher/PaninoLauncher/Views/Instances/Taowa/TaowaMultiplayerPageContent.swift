import SwiftUI

struct TaowaMultiplayerPageContent: View {
    let isLoading: Bool
    let isWorking: Bool
    let errorText: String?
    let copyStatus: String
    let statusText: String
    let connectionStateTitle: String
    let connectionBadgeStyle: StatusBadge.Style
    let workflowSteps: [TaowaWorkflowStep]
    let profiles: [CoreTaowaFrpProfile]
    @Binding var selectedProfileId: String
    let editingProfileId: String?
    @Binding var profileDraft: TaowaProfileDraft
    let profileTest: CoreTaowaFrpProfileTestResponse?
    let activeSessionForProfile: (String) -> CoreTaowaSession?
    let instance: GameInstance
    @Binding var localPortText: String
    let detection: CoreTaowaLanPortDetection?
    let startRequirements: [TaowaRequirement]
    let startHintText: String?
    let hasParsedLocalPort: Bool
    let canStartTunnel: Bool
    let runningSession: CoreTaowaSession?
    let displaySession: CoreTaowaSession?
    let relevantSessions: [CoreTaowaSession]
    let health: CoreTaowaSessionHealthResponse?
    let logTail: String
    let activeDiagnostics: [CoreDiagnostic]?
    let onRefresh: () -> Void
    let onNewProfile: () -> Void
    let onCopyAddress: (String, String) -> Void
    let onChooseFrpc: () -> Void
    let onSaveProfile: () -> Void
    let onTestProfile: (String) -> Void
    let onDeleteProfile: (String) -> Void
    let onDetectLanPort: () -> Void
    let onValidatePort: () -> Void
    let onStartSession: () -> Void
    let onStopSession: (CoreTaowaSession) -> Void
    let onClearHistory: () -> Void
    let onLoadLog: (CoreTaowaSession) -> Void
    let onReloadSession: (CoreTaowaSession) -> Void
    let onLoadHealth: (CoreTaowaSession) async -> Void
    let onSelectSession: (CoreTaowaSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TaowaHeaderPanel(
                isLoading: isLoading,
                isWorking: isWorking,
                errorText: errorText,
                copyStatus: copyStatus,
                statusText: statusText,
                connectionStateTitle: connectionStateTitle,
                connectionBadgeStyle: connectionBadgeStyle
            )

            TaowaWorkflowPanel(workflowSteps: workflowSteps)

            TaowaProfilePanel(
                profiles: profiles,
                selectedProfileId: $selectedProfileId,
                editingProfileId: editingProfileId,
                profileDraft: $profileDraft,
                profileTest: profileTest,
                isWorking: isWorking,
                activeSessionForProfile: activeSessionForProfile,
                onRefresh: onRefresh,
                onNewProfile: onNewProfile,
                onCopyAddress: onCopyAddress,
                onChooseFrpc: onChooseFrpc,
                onSave: onSaveProfile,
                onTest: onTestProfile,
                onDelete: onDeleteProfile
            )

            TaowaTunnelPanel(
                instance: instance,
                localPortText: $localPortText,
                detection: detection,
                startRequirements: startRequirements,
                startHintText: startHintText,
                isWorking: isWorking,
                hasParsedLocalPort: hasParsedLocalPort,
                canStartTunnel: canStartTunnel,
                runningSession: runningSession,
                onDetectLanPort: onDetectLanPort,
                onValidatePort: onValidatePort,
                onStartSession: onStartSession,
                onStopSession: onStopSession,
                onClearHistory: onClearHistory
            )

            if let displaySession {
                TaowaSessionPanel(
                    session: displaySession,
                    health: health,
                    logTail: logTail,
                    onCopyAddress: onCopyAddress,
                    onLoadLog: onLoadLog,
                    onReloadSession: onReloadSession,
                    onLoadHealth: onLoadHealth
                )
            }

            if !relevantSessions.isEmpty {
                TaowaSessionHistoryPanel(
                    sessions: relevantSessions,
                    selectedSessionId: displaySession?.sessionId,
                    onSelect: onSelectSession
                )
            }

            if let activeDiagnostics, !activeDiagnostics.isEmpty {
                TaowaDiagnosticsPanel(diagnostics: activeDiagnostics)
            }
        }
    }
}
