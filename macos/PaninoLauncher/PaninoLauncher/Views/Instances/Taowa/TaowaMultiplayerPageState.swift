import SwiftUI

extension TaowaMultiplayerPage {
    var displaySession: CoreTaowaSession? {
        if let selectedSessionId,
           let selected = relevantSessions.first(where: { $0.sessionId == selectedSessionId }) {
            return selected
        }
        if let running = runningSession {
            return running
        }
        return relevantSessions.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    var runningSession: CoreTaowaSession? {
        relevantSessions.sorted { $0.updatedAt > $1.updatedAt }.first { $0.isRunning }
    }

    var relevantSessions: [CoreTaowaSession] {
        let instanceId = instance.id.uuidString
        let gameDir = standardizedPath(instance.gameDirectory)
        return sessions.filter { session in
            session.instanceId == instanceId || standardizedPath(session.gameDir) == gameDir
        }
    }

    var activeDiagnostics: [CoreDiagnostic]? {
        if let diagnostics = profileTest?.diagnostics, !diagnostics.isEmpty {
            return diagnostics
        }
        if let diagnostics = detection?.diagnostics, !diagnostics.isEmpty {
            return diagnostics
        }
        return displaySession?.diagnostics
    }

    var parsedLocalPort: Int? {
        let trimmed = localPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (1...65535).contains(value) else { return nil }
        return value
    }

    var selectedProfile: CoreTaowaFrpProfile? {
        profiles.first { $0.profileId == selectedProfileId }
    }

    var canStartTunnel: Bool {
        selectedProfile?.enabled == true &&
        parsedLocalPort != nil &&
        runningSession == nil &&
        !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var startHintText: String? {
        TaowaMultiplayerPresentation.startHintText(
            language: theme.language,
            selectedProfile: selectedProfile,
            parsedLocalPort: parsedLocalPort,
            runningSession: runningSession,
            detection: detection
        )
    }

    var workflowSteps: [TaowaWorkflowStep] {
        TaowaMultiplayerPresentation.workflowSteps(
            language: theme.language,
            selectedProfile: selectedProfile,
            parsedLocalPort: parsedLocalPort,
            detection: detection,
            runningSession: runningSession
        )
    }

    var startRequirements: [TaowaRequirement] {
        TaowaMultiplayerPresentation.startRequirements(
            language: theme.language,
            selectedProfile: selectedProfile,
            parsedLocalPort: parsedLocalPort,
            detection: detection,
            runningSession: runningSession
        )
    }

    var connectionStateTitle: String {
        TaowaMultiplayerPresentation.connectionStateTitle(
            language: theme.language,
            runningSession: runningSession,
            displaySession: displaySession
        )
    }

    var connectionBadgeStyle: StatusBadge.Style {
        TaowaMultiplayerPresentation.connectionBadgeStyle(
            runningSession: runningSession,
            displaySession: displaySession
        )
    }

    func activeSessionForProfile(_ profileId: String) -> CoreTaowaSession? {
        sessions.first { $0.profileId == profileId && $0.isActive }
    }

    func standardizedPath(_ value: String) -> String {
        URL(fileURLWithPath: value).standardizedFileURL.path
    }
}
