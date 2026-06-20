import AppKit
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

    func saveProfile() async {
        guard let request = profileDraft.request(profileId: editingProfileId) else {
            errorText = localizedString(theme.language, english: "Fill server address, ports, and frpc path.", chinese: "请填写服务器地址、端口和 frpc 路径。", italian: "Compila server, porte e percorso frpc.", french: "Renseignez serveur, ports et chemin frpc.", spanish: "Completa servidor, puertos y ruta frpc.")
            return
        }
        isWorking = true
        errorText = nil
        do {
            let saved = try await viewModel.saveTaowaFrpProfile(profileId: editingProfileId, request: request)
            selectedProfileId = saved.profileId
            profileTest = nil
            statusText = localizedString(theme.language, english: "FRP profile saved.", chinese: "FRP 配置已保存。", italian: "Profilo FRP salvato.", french: "Profil FRP enregistré.", spanish: "Perfil FRP guardado.")
            await loadState()
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func testProfile(_ profileId: String) async {
        isWorking = true
        errorText = nil
        do {
            let response = try await viewModel.testTaowaFrpProfile(profileId: profileId)
            profileTest = response
            statusText = response.ok
                ? localizedString(theme.language, english: "FRP profile test passed.", chinese: "FRP 配置测试通过。", italian: "Test profilo FRP riuscito.", french: "Test du profil FRP réussi.", spanish: "Prueba del perfil FRP superada.")
                : localizedString(theme.language, english: "FRP profile test found issues.", chinese: "FRP 配置测试发现问题。", italian: "Test profilo FRP con problemi.", french: "Le test du profil FRP a trouvé des problèmes.", spanish: "La prueba del perfil FRP encontró problemas.")
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func deleteProfile(_ profileId: String) async {
        isWorking = true
        errorText = nil
        do {
            _ = try await viewModel.deleteTaowaFrpProfile(profileId: profileId)
            startNewProfile()
            profileTest = nil
            statusText = localizedString(theme.language, english: "FRP profile deleted.", chinese: "FRP 配置已删除。", italian: "Profilo FRP eliminato.", french: "Profil FRP supprimé.", spanish: "Perfil FRP eliminado.")
            await loadState()
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func detectLanPort() async {
        isWorking = true
        errorText = nil
        do {
            let response = try await viewModel.taowaLanDetect(
                CoreTaowaLanDetectRequest(
                    instanceId: instance.id.uuidString,
                    gameDir: instance.gameDirectory,
                    timeoutSeconds: 45
                )
            )
            detection = response
            if let port = response.detectedPort {
                localPortText = String(port)
            }
            statusText = response.isDetected
                ? localizedString(theme.language, english: "LAN port detected and reachable.", chinese: "已检测到可连接的 LAN 端口。", italian: "Porta LAN rilevata.", french: "Port LAN détecté.", spanish: "Puerto LAN detectado.")
                : localizedString(theme.language, english: "LAN port was not detected. Enter the port shown by Minecraft.", chinese: "未检测到 LAN 端口，请输入 Minecraft 显示的端口。", italian: "Porta LAN non rilevata.", french: "Port LAN non détecté.", spanish: "Puerto LAN no detectado.")
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func validatePort() async {
        guard let port = parsedLocalPort else { return }
        isWorking = true
        errorText = nil
        do {
            let response = try await viewModel.taowaValidatePort(
                CoreTaowaLanValidatePortRequest(
                    instanceId: instance.id.uuidString,
                    gameDir: instance.gameDirectory,
                    localPort: port
                )
            )
            detection = response
            statusText = localizedString(theme.language, english: "LAN port validated.", chinese: "LAN 端口已校验。", italian: "Porta LAN validata.", french: "Port LAN validé.", spanish: "Puerto LAN validado.")
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func startSession() async {
        guard let port = parsedLocalPort, !selectedProfileId.isEmpty else { return }
        isWorking = true
        errorText = nil
        do {
            let session = try await viewModel.startTaowaSession(
                CoreTaowaSessionStartRequest(
                    profileId: selectedProfileId,
                    instanceId: instance.id.uuidString,
                    gameDir: instance.gameDirectory,
                    localPort: port
                )
            )
            sessions = [session] + sessions.filter { $0.sessionId != session.sessionId }
            selectedSessionId = session.sessionId
            logTail = ""
            statusText = localizedString(theme.language, english: "Taowa tunnel started.", chinese: "陶瓦联机隧道已启动。", italian: "Tunnel Taowa avviato.", french: "Tunnel Taowa démarré.", spanish: "Túnel Taowa iniciado.")
            await loadHealth(session)
        } catch {
            errorText = error.localizedDescription
            await loadState()
        }
        isWorking = false
    }

    func stopSession(_ session: CoreTaowaSession) async {
        isWorking = true
        errorText = nil
        do {
            let stopped = try await viewModel.stopTaowaSession(sessionId: session.sessionId)
            sessions = [stopped] + sessions.filter { $0.sessionId != stopped.sessionId }
            selectedSessionId = stopped.sessionId
            statusText = localizedString(theme.language, english: "Taowa tunnel stopped.", chinese: "陶瓦联机隧道已停止。", italian: "Tunnel Taowa fermato.", french: "Tunnel Taowa arrêté.", spanish: "Túnel Taowa detenido.")
            await loadHealth(stopped)
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func loadLog(_ session: CoreTaowaSession) async {
        isWorking = true
        errorText = nil
        do {
            let response = try await viewModel.taowaSessionLog(sessionId: session.sessionId)
            logTail = response.tail
            statusText = localizedString(theme.language, english: "frpc log loaded.", chinese: "frpc 日志已读取。", italian: "Log frpc caricato.", french: "Journal frpc chargé.", spanish: "Registro frpc cargado.")
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func reloadSession(_ session: CoreTaowaSession) async {
        isWorking = true
        errorText = nil
        do {
            let refreshed = try await viewModel.taowaSession(sessionId: session.sessionId)
            sessions = [refreshed] + sessions.filter { $0.sessionId != refreshed.sessionId }
            selectedSessionId = refreshed.sessionId
            statusText = localizedString(theme.language, english: "Taowa session refreshed.", chinese: "陶瓦联机会话已刷新。", italian: "Sessione Taowa aggiornata.", french: "Session Taowa actualisée.", spanish: "Sesión Taowa actualizada.")
            await loadHealth(refreshed)
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func loadHealth(_ session: CoreTaowaSession) async {
        do {
            health = try await viewModel.taowaSessionHealth(sessionId: session.sessionId)
        } catch {
            health = nil
        }
    }

    func clearHistory() async {
        isWorking = true
        errorText = nil
        do {
            let response = try await viewModel.clearTaowaSessionHistory(
                CoreTaowaSessionHistoryClearRequest(statuses: ["stopped", "failed"], keepActive: true)
            )
            statusText = localizedString(theme.language, english: "Cleared \(response.deleted) Taowa session records.", chinese: "已清理 \(response.deleted) 条陶瓦联机会话记录。", italian: "Pulite \(response.deleted) sessioni Taowa.", french: "\(response.deleted) sessions Taowa effacées.", spanish: "\(response.deleted) sesiones Taowa eliminadas.")
            selectedSessionId = runningSession?.sessionId
            await loadState()
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func startNewProfile() {
        selectedProfileId = ""
        editingProfileId = nil
        profileDraft = TaowaProfileDraft()
    }

    func loadSelectedProfileIntoDraft() {
        guard let profile = profiles.first(where: { $0.profileId == selectedProfileId }) else {
            editingProfileId = nil
            if selectedProfileId.isEmpty {
                profileDraft = TaowaProfileDraft()
                profileTest = nil
            }
            return
        }
        editingProfileId = profile.profileId
        profileDraft = TaowaProfileDraft(profile: profile)
        if profileTest?.profileId != profile.profileId {
            profileTest = nil
        }
    }

    func selectSession(_ session: CoreTaowaSession) {
        selectedSessionId = session.sessionId
        if session.status == "failed" || session.status == "stopped" {
            Task { await loadLog(session) }
        } else {
            Task { await loadHealth(session) }
        }
    }

    func chooseFrpc() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = localizedString(theme.language, english: "Choose the frpc executable from your FRP provider.", chinese: "选择第三方 FRP 服务提供的 frpc 可执行文件。", italian: "Scegli eseguibile frpc.", french: "Choisissez l'exécutable frpc.", spanish: "Elige el ejecutable frpc.")
        if panel.runModal() == .OK, let url = panel.url {
            profileDraft.frpcPath = url.path
        }
    }

    func copy(_ value: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copyStatus = message
        errorText = nil
    }
}
