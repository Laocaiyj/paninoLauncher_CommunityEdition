import SwiftUI

struct TaowaMultiplayerPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let instance: GameInstance

    @EnvironmentObject var theme: ThemeSettings

    @State var profiles: [CoreTaowaFrpProfile] = []
    @State var sessions: [CoreTaowaSession] = []
    @State var selectedProfileId = ""
    @State var selectedSessionId: String?
    @State var editingProfileId: String?
    @State var profileDraft = TaowaProfileDraft()
    @State var localPortText = ""
    @State var detection: CoreTaowaLanPortDetection?
    @State var profileTest: CoreTaowaFrpProfileTestResponse?
    @State var health: CoreTaowaSessionHealthResponse?
    @State var logTail = ""
    @State var statusText = ""
    @State var errorText: String?
    @State var copyStatus = ""
    @State var isLoading = false
    @State var isWorking = false

    var body: some View {
        TaowaMultiplayerPageContent(
            isLoading: isLoading,
            isWorking: isWorking,
            errorText: errorText,
            copyStatus: copyStatus,
            statusText: statusText,
            connectionStateTitle: connectionStateTitle,
            connectionBadgeStyle: connectionBadgeStyle,
            workflowSteps: workflowSteps,
            profiles: profiles,
            selectedProfileId: $selectedProfileId,
            editingProfileId: editingProfileId,
            profileDraft: $profileDraft,
            profileTest: profileTest,
            activeSessionForProfile: activeSessionForProfile,
            instance: instance,
            localPortText: $localPortText,
            detection: detection,
            startRequirements: startRequirements,
            startHintText: startHintText,
            hasParsedLocalPort: parsedLocalPort != nil,
            canStartTunnel: canStartTunnel,
            runningSession: runningSession,
            displaySession: displaySession,
            relevantSessions: relevantSessions,
            health: health,
            logTail: logTail,
            activeDiagnostics: activeDiagnostics,
            onRefresh: { Task { await loadState() } },
            onNewProfile: startNewProfile,
            onCopyAddress: copy,
            onChooseFrpc: chooseFrpc,
            onSaveProfile: { Task { await saveProfile() } },
            onTestProfile: { profileId in Task { await testProfile(profileId) } },
            onDeleteProfile: { profileId in Task { await deleteProfile(profileId) } },
            onDetectLanPort: { Task { await detectLanPort() } },
            onValidatePort: { Task { await validatePort() } },
            onStartSession: { Task { await startSession() } },
            onStopSession: { session in Task { await stopSession(session) } },
            onClearHistory: { Task { await clearHistory() } },
            onLoadLog: { session in Task { await loadLog(session) } },
            onReloadSession: { session in Task { await reloadSession(session) } },
            onLoadHealth: loadHealth,
            onSelectSession: selectSession
        )
        .task(id: instance.id) {
            await loadState()
        }
        .onChange(of: selectedProfileId) {
            loadSelectedProfileIntoDraft()
        }
    }
}
