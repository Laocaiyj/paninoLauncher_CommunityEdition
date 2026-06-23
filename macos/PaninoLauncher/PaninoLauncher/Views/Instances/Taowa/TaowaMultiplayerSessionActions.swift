import SwiftUI

extension TaowaMultiplayerPage {
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

    func selectSession(_ session: CoreTaowaSession) {
        selectedSessionId = session.sessionId
        if session.status == "failed" || session.status == "stopped" {
            Task { await loadLog(session) }
        } else {
            Task { await loadHealth(session) }
        }
    }
}
