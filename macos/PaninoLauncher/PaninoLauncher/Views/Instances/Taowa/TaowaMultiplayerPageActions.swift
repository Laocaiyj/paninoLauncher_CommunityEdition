import SwiftUI

extension TaowaMultiplayerPage {
    func loadState() async {
        isLoading = true
        errorText = nil
        do {
            let loadedProfiles = try await viewModel.taowaFrpProfiles().profiles
            let loadedSessions = try await viewModel.taowaSessions().sessions
            profiles = loadedProfiles.sorted { $0.updatedAt > $1.updatedAt }
            sessions = loadedSessions
            if selectedProfileId.isEmpty {
                selectedProfileId = profiles.first(where: \.enabled)?.profileId ?? profiles.first?.profileId ?? ""
            }
            loadSelectedProfileIntoDraft()
            if let session = displaySession {
                localPortText = String(session.localPort)
                selectedSessionId = session.sessionId
                await loadHealth(session)
            }
            statusText = localizedString(theme.language, english: "Taowa state refreshed.", chinese: "陶瓦联机状态已刷新。", italian: "Stato Taowa aggiornato.", french: "État Taowa actualisé.", spanish: "Estado Taowa actualizado.")
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}
