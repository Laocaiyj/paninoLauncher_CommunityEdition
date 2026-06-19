import AppKit
import SwiftUI

struct TaowaMultiplayerPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let instance: GameInstance

    @EnvironmentObject private var theme: ThemeSettings

    @State private var profiles: [CoreTaowaFrpProfile] = []
    @State private var sessions: [CoreTaowaSession] = []
    @State private var selectedProfileId = ""
    @State private var selectedSessionId: String?
    @State private var editingProfileId: String?
    @State private var profileDraft = TaowaProfileDraft()
    @State private var localPortText = ""
    @State private var detection: CoreTaowaLanPortDetection?
    @State private var profileTest: CoreTaowaFrpProfileTestResponse?
    @State private var health: CoreTaowaSessionHealthResponse?
    @State private var logTail = ""
    @State private var statusText = ""
    @State private var errorText: String?
    @State private var copyStatus = ""
    @State private var isLoading = false
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerPanel
            workflowPanel
            profilePanel
            tunnelPanel
            if let session = displaySession {
                sessionPanel(session)
            }
            if !relevantSessions.isEmpty {
                sessionHistoryPanel
            }
            if let diagnostics = activeDiagnostics, !diagnostics.isEmpty {
                diagnosticsPanel(diagnostics)
            }
        }
        .task(id: instance.id) {
            await loadState()
        }
        .onChange(of: selectedProfileId) {
            loadSelectedProfileIntoDraft()
        }
    }

    private var headerPanel: some View {
        TaowaHeaderPanel(
            isLoading: isLoading,
            isWorking: isWorking,
            errorText: errorText,
            copyStatus: copyStatus,
            statusText: statusText,
            connectionStateTitle: connectionStateTitle,
            connectionBadgeStyle: connectionBadgeStyle
        )
    }

    private var workflowPanel: some View {
        TaowaWorkflowPanel(workflowSteps: workflowSteps)
    }

    private var profilePanel: some View {
        TaowaProfilePanel(
            profiles: profiles,
            selectedProfileId: $selectedProfileId,
            editingProfileId: editingProfileId,
            profileDraft: $profileDraft,
            profileTest: profileTest,
            isWorking: isWorking,
            activeSessionForProfile: activeSessionForProfile,
            onRefresh: { Task { await loadState() } },
            onNewProfile: startNewProfile,
            onCopyAddress: copy,
            onChooseFrpc: chooseFrpc,
            onSave: { Task { await saveProfile() } },
            onTest: { profileId in Task { await testProfile(profileId) } },
            onDelete: { profileId in Task { await deleteProfile(profileId) } }
        )
    }

    private var tunnelPanel: some View {
        TaowaTunnelPanel(
            instance: instance,
            localPortText: $localPortText,
            detection: detection,
            startRequirements: startRequirements,
            startHintText: startHintText,
            isWorking: isWorking,
            hasParsedLocalPort: parsedLocalPort != nil,
            canStartTunnel: canStartTunnel,
            runningSession: runningSession,
            onDetectLanPort: { Task { await detectLanPort() } },
            onValidatePort: { Task { await validatePort() } },
            onStartSession: { Task { await startSession() } },
            onStopSession: { session in Task { await stopSession(session) } },
            onClearHistory: { Task { await clearHistory() } }
        )
    }

    private func sessionPanel(_ session: CoreTaowaSession) -> some View {
        TaowaSessionPanel(
            session: session,
            health: health,
            logTail: logTail,
            onCopyAddress: copy,
            onLoadLog: { session in Task { await loadLog(session) } },
            onReloadSession: { session in Task { await reloadSession(session) } },
            onLoadHealth: loadHealth
        )
    }

    private var sessionHistoryPanel: some View {
        TaowaSessionHistoryPanel(
            sessions: relevantSessions,
            selectedSessionId: displaySession?.sessionId,
            onSelect: selectSession
        )
    }

    private func diagnosticsPanel(_ diagnostics: [CoreDiagnostic]) -> some View {
        TaowaDiagnosticsPanel(diagnostics: diagnostics)
    }

    private var displaySession: CoreTaowaSession? {
        if let selectedSessionId,
           let selected = relevantSessions.first(where: { $0.sessionId == selectedSessionId }) {
            return selected
        }
        if let running = runningSession {
            return running
        }
        return relevantSessions.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    private var runningSession: CoreTaowaSession? {
        relevantSessions.sorted { $0.updatedAt > $1.updatedAt }.first { $0.isRunning }
    }

    private var relevantSessions: [CoreTaowaSession] {
        let instanceId = instance.id.uuidString
        let gameDir = standardizedPath(instance.gameDirectory)
        return sessions.filter { session in
            session.instanceId == instanceId || standardizedPath(session.gameDir) == gameDir
        }
    }

    private var activeDiagnostics: [CoreDiagnostic]? {
        if let diagnostics = profileTest?.diagnostics, !diagnostics.isEmpty {
            return diagnostics
        }
        if let diagnostics = detection?.diagnostics, !diagnostics.isEmpty {
            return diagnostics
        }
        return displaySession?.diagnostics
    }

    private var parsedLocalPort: Int? {
        let trimmed = localPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (1...65535).contains(value) else { return nil }
        return value
    }

    private var selectedProfile: CoreTaowaFrpProfile? {
        profiles.first { $0.profileId == selectedProfileId }
    }

    private var canStartTunnel: Bool {
        selectedProfile?.enabled == true &&
        parsedLocalPort != nil &&
        runningSession == nil &&
        !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var startHintText: String? {
        if selectedProfile == nil {
            return localizedString(theme.language, english: "Choose or save an FRP profile before starting.", chinese: "启动前请选择或保存一个 FRP 配置。", italian: "Scegli o salva un profilo FRP prima di avviare.", french: "Choisissez ou enregistrez un profil FRP avant de démarrer.", spanish: "Elige o guarda un perfil FRP antes de iniciar.")
        }
        if selectedProfile?.enabled == false {
            return localizedString(theme.language, english: "The selected FRP profile is disabled.", chinese: "当前 FRP 配置已停用。", italian: "Il profilo FRP selezionato è disabilitato.", french: "Le profil FRP sélectionné est désactivé.", spanish: "El perfil FRP seleccionado está desactivado.")
        }
        if parsedLocalPort == nil {
            return localizedString(theme.language, english: "Open the world to LAN in Minecraft, then detect or enter the LAN port.", chinese: "先在 Minecraft 单人世界中“对局域网开放”，再检测或输入 LAN 端口。", italian: "Apri il mondo alla LAN, poi rileva o inserisci la porta.", french: "Ouvrez le monde au LAN, puis détectez ou saisissez le port.", spanish: "Abre el mundo a LAN y luego detecta o introduce el puerto.")
        }
        if runningSession != nil {
            return localizedString(theme.language, english: "A Taowa tunnel is already running for this instance.", chinese: "这个实例已经有正在运行的陶瓦隧道。", italian: "Un tunnel Taowa è già in esecuzione.", french: "Un tunnel Taowa est déjà en cours.", spanish: "Ya hay un túnel Taowa en ejecución.")
        }
        if detection?.isDetected != true {
            return localizedString(theme.language, english: "Port validation is recommended. Core will still verify the port before starting frpc.", chinese: "建议先校验端口。启动时 Core 仍会再次校验本地端口。", italian: "La verifica della porta è consigliata.", french: "La validation du port est recommandée.", spanish: "Se recomienda validar el puerto.")
        }
        return nil
    }

    private var workflowSteps: [TaowaWorkflowStep] {
        [
            TaowaWorkflowStep(
                id: "profile",
                title: localizedString(theme.language, english: "FRP profile", chinese: "FRP 配置", italian: "Profilo FRP", french: "Profil FRP", spanish: "Perfil FRP"),
                detail: selectedProfile?.displayName ?? localizedString(theme.language, english: "Create or choose one", chinese: "新建或选择一个配置", italian: "Crea o scegli", french: "Créer ou choisir", spanish: "Crear o elegir"),
                systemImage: "server.rack",
                style: selectedProfile?.enabled == true ? .success : .warning,
                isReady: selectedProfile?.enabled == true
            ),
            TaowaWorkflowStep(
                id: "lan",
                title: localizedString(theme.language, english: "LAN port", chinese: "LAN 端口", italian: "Porta LAN", french: "Port LAN", spanish: "Puerto LAN"),
                detail: parsedLocalPort.map { String($0) } ?? localizedString(theme.language, english: "Detect after opening to LAN", chinese: "对局域网开放后检测", italian: "Rileva dopo apertura LAN", french: "Détecter après ouverture LAN", spanish: "Detectar tras abrir LAN"),
                systemImage: "number",
                style: parsedLocalPort == nil ? .warning : (detection?.isDetected == true ? .success : .neutral),
                isReady: parsedLocalPort != nil
            ),
            TaowaWorkflowStep(
                id: "session",
                title: localizedString(theme.language, english: "Tunnel", chinese: "隧道", italian: "Tunnel", french: "Tunnel", spanish: "Túnel"),
                detail: runningSession?.remoteAddress ?? localizedString(theme.language, english: "Start when ready", chinese: "准备好后启动", italian: "Avvia quando pronto", french: "Démarrer quand prêt", spanish: "Iniciar cuando esté listo"),
                systemImage: "link",
                style: runningSession == nil ? .neutral : .running,
                isReady: runningSession != nil
            )
        ]
    }

    private var startRequirements: [TaowaRequirement] {
        [
            TaowaRequirement(
                id: "profile",
                title: localizedString(theme.language, english: "FRP profile selected", chinese: "已选择 FRP 配置", italian: "Profilo FRP selezionato", french: "Profil FRP sélectionné", spanish: "Perfil FRP seleccionado"),
                state: selectedProfile == nil ? .missing : (selectedProfile?.enabled == true ? .ready : .warning)
            ),
            TaowaRequirement(
                id: "port",
                title: localizedString(theme.language, english: "LAN port entered", chinese: "已填写 LAN 端口", italian: "Porta LAN inserita", french: "Port LAN saisi", spanish: "Puerto LAN introducido"),
                state: parsedLocalPort == nil ? .missing : (detection?.isDetected == true ? .ready : .warning)
            ),
            TaowaRequirement(
                id: "session",
                title: localizedString(theme.language, english: "No running tunnel", chinese: "没有正在运行的隧道", italian: "Nessun tunnel attivo", french: "Aucun tunnel actif", spanish: "Sin túnel activo"),
                state: runningSession == nil ? .ready : .missing
            )
        ]
    }

    private var connectionStateTitle: String {
        if runningSession != nil {
            return localizedString(theme.language, english: "Running", chinese: "运行中", italian: "In esecuzione", french: "En cours", spanish: "En ejecución")
        }
        if displaySession?.status == "failed" {
            return AppText.failed.localized(theme.language)
        }
        return localizedString(theme.language, english: "Ready", chinese: "就绪", italian: "Pronto", french: "Prêt", spanish: "Listo")
    }

    private var connectionBadgeStyle: StatusBadge.Style {
        if runningSession != nil { return .running }
        if displaySession?.status == "failed" { return .error }
        return .neutral
    }

    private func loadState() async {
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

    private func saveProfile() async {
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

    private func testProfile(_ profileId: String) async {
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

    private func deleteProfile(_ profileId: String) async {
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

    private func detectLanPort() async {
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

    private func validatePort() async {
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

    private func startSession() async {
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

    private func stopSession(_ session: CoreTaowaSession) async {
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

    private func loadLog(_ session: CoreTaowaSession) async {
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

    private func reloadSession(_ session: CoreTaowaSession) async {
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

    private func loadHealth(_ session: CoreTaowaSession) async {
        do {
            health = try await viewModel.taowaSessionHealth(sessionId: session.sessionId)
        } catch {
            health = nil
        }
    }

    private func clearHistory() async {
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

    private func startNewProfile() {
        selectedProfileId = ""
        editingProfileId = nil
        profileDraft = TaowaProfileDraft()
    }

    private func loadSelectedProfileIntoDraft() {
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

    private func activeSessionForProfile(_ profileId: String) -> CoreTaowaSession? {
        sessions.first { $0.profileId == profileId && $0.isActive }
    }

    private func selectSession(_ session: CoreTaowaSession) {
        selectedSessionId = session.sessionId
        if session.status == "failed" || session.status == "stopped" {
            Task { await loadLog(session) }
        } else {
            Task { await loadHealth(session) }
        }
    }

    private func chooseFrpc() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = localizedString(theme.language, english: "Choose the frpc executable from your FRP provider.", chinese: "选择第三方 FRP 服务提供的 frpc 可执行文件。", italian: "Scegli eseguibile frpc.", french: "Choisissez l'exécutable frpc.", spanish: "Elige el ejecutable frpc.")
        if panel.runModal() == .OK, let url = panel.url {
            profileDraft.frpcPath = url.path
        }
    }

    private func copy(_ value: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copyStatus = message
        errorText = nil
    }

    private func standardizedPath(_ value: String) -> String {
        URL(fileURLWithPath: value).standardizedFileURL.path
    }
}
