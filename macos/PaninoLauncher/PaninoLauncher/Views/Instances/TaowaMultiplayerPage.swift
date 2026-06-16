import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
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
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Taowa Multiplayer", chinese: "陶瓦联机", italian: "Multigiocatore Taowa", french: "Multijoueur Taowa", spanish: "Multijugador Taowa"),
                        systemImage: "network"
                    )
                    Spacer()
                    StatusBadge(title: connectionStateTitle, style: connectionBadgeStyle)
                }

                Text(localizedString(
                    theme.language,
                    english: "Panino does not provide public routes. Use your own third-party FRP service, then share the generated address with friends.",
                    chinese: "Panino 不提供公网线路。请使用你自备的第三方 FRP 服务，再把生成的地址发给好友。",
                    italian: "Panino non fornisce linee pubbliche. Usa un servizio FRP di terze parti.",
                    french: "Panino ne fournit pas de ligne publique. Utilisez votre propre service FRP tiers.",
                    spanish: "Panino no proporciona rutas públicas. Usa tu propio servicio FRP de terceros."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if isLoading || isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
                statusLine
            }
        }
    }

    private var workflowPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Connection Flow", chinese: "联机流程", italian: "Flusso connessione", french: "Flux de connexion", spanish: "Flujo de conexión"),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                    Spacer()
                    StatusBadge(title: "\(workflowSteps.filter(\.isReady).count)/\(workflowSteps.count)", style: workflowSteps.allSatisfy(\.isReady) ? .success : .warning)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                    ForEach(workflowSteps) { step in
                        TaowaStepCard(step: step)
                    }
                }
            }
        }
    }

    private var profilePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "FRP Profile", chinese: "FRP 配置", italian: "Profilo FRP", french: "Profil FRP", spanish: "Perfil FRP"),
                        systemImage: "server.rack"
                    )
                    Spacer()
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                        Task { await loadState() }
                    }
                    .disabled(isWorking)
                    GlassButton(systemImage: "plus", title: localizedString(theme.language, english: "New", chinese: "新建", italian: "Nuovo", french: "Nouveau", spanish: "Nuevo")) {
                        startNewProfile()
                    }
                    .disabled(isWorking)
                }

                SettingsRow(title: localizedString(theme.language, english: "Profile", chinese: "配置", italian: "Profilo", french: "Profil", spanish: "Perfil"), systemImage: "list.bullet") {
                    Picker("", selection: $selectedProfileId) {
                        Text(localizedString(theme.language, english: "New Profile", chinese: "新配置", italian: "Nuovo profilo", french: "Nouveau profil", spanish: "Nuevo perfil"))
                            .tag("")
                        ForEach(profiles) { profile in
                            Text(profile.displayName).tag(profile.profileId)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 360, alignment: .leading)
                }

                if !profiles.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                        ForEach(profiles) { profile in
                            TaowaProfileCard(
                                profile: profile,
                                isSelected: profile.profileId == selectedProfileId,
                                hasActiveSession: activeSessionForProfile(profile.profileId) != nil,
                                onSelect: {
                                    selectedProfileId = profile.profileId
                                },
                                onCopyAddress: {
                                    copy(profile.remoteAddress, message: localizedString(theme.language, english: "Profile remote address copied.", chinese: "配置远程地址已复制。", italian: "Indirizzo remoto copiato.", french: "Adresse distante copiée.", spanish: "Dirección remota copiada."))
                                }
                            )
                        }
                    }
                }

                if let profileTest {
                    TaowaProfileTestPanel(test: profileTest)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 10) {
                    SettingsRow(title: localizedString(theme.language, english: "Name", chinese: "名称", italian: "Nome", french: "Nom", spanish: "Nombre"), systemImage: "tag") {
                        PaninoTextInput("My FRP", text: $profileDraft.displayName)
                    }
                    SettingsRow(title: "Server", systemImage: "network") {
                        PaninoTextInput("frp.example.com", text: $profileDraft.serverAddr)
                    }
                    SettingsRow(title: "Server Port", systemImage: "number") {
                        PaninoTextInput("7000", text: $profileDraft.serverPort)
                    }
                    SettingsRow(title: "Remote Port", systemImage: "number.circle") {
                        PaninoTextInput("25565", text: $profileDraft.remotePort)
                    }
                    SettingsRow(title: "Token", systemImage: "key") {
                        PaninoTextInput(profileDraft.hasExistingToken ? "Keep existing token" : "Optional", text: $profileDraft.token, isSecure: true)
                    }
                    SettingsRow(title: "frpc", systemImage: "terminal") {
                        HStack(spacing: 8) {
                            PaninoTextInput("/path/to/frpc", text: $profileDraft.frpcPath)
                            GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Choose", chinese: "选择", italian: "Scegli", french: "Choisir", spanish: "Elegir")) {
                                chooseFrpc()
                            }
                        }
                    }
                    SettingsRow(title: localizedString(theme.language, english: "Enabled", chinese: "启用", italian: "Abilitato", french: "Activé", spanish: "Activado"), systemImage: "checkmark.circle") {
                        Toggle("", isOn: $profileDraft.enabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                HStack(spacing: 8) {
                    GlassButton(systemImage: "checkmark", title: localizedString(theme.language, english: "Save", chinese: "保存", italian: "Salva", french: "Enregistrer", spanish: "Guardar"), prominent: true) {
                        Task { await saveProfile() }
                    }
                    .disabled(isWorking)
                    if let editingProfileId {
                        GlassButton(systemImage: "checkmark.shield", title: localizedString(theme.language, english: "Test", chinese: "测试", italian: "Test", french: "Tester", spanish: "Probar")) {
                            Task { await testProfile(editingProfileId) }
                        }
                        .disabled(isWorking)
                        GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language)) {
                            Task { await deleteProfile(editingProfileId) }
                        }
                        .disabled(isWorking || activeSessionForProfile(editingProfileId) != nil)
                    }
                }
            }
        }
    }

    private var tunnelPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "LAN Tunnel", chinese: "局域网隧道", italian: "Tunnel LAN", french: "Tunnel LAN", spanish: "Túnel LAN"),
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                    Spacer()
                    if let detection {
                        StatusBadge(title: detection.status, style: detection.isDetected ? .success : .warning)
                    }
                }

                SettingsRow(title: localizedString(theme.language, english: "Instance", chinese: "实例", italian: "Istanza", french: "Instance", spanish: "Instancia"), systemImage: "cube.box") {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(instance.name)
                            .font(.callout.weight(.semibold))
                        Text(instance.gameDirectory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }

                SettingsRow(title: localizedString(theme.language, english: "LAN Port", chinese: "LAN 端口", italian: "Porta LAN", french: "Port LAN", spanish: "Puerto LAN"), systemImage: "number") {
                    HStack(spacing: 8) {
                        PaninoTextInput("Minecraft LAN port", text: $localPortText)
                            .frame(maxWidth: 180)
                        GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Detect", chinese: "检测", italian: "Rileva", french: "Détecter", spanish: "Detectar")) {
                            Task { await detectLanPort() }
                        }
                        .disabled(isWorking || instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        GlassButton(systemImage: "checkmark.seal", title: localizedString(theme.language, english: "Validate", chinese: "校验", italian: "Valida", french: "Valider", spanish: "Validar")) {
                            Task { await validatePort() }
                        }
                        .disabled(isWorking || parsedLocalPort == nil)
                    }
                }

                if let evidence = detection?.evidence, !evidence.isEmpty {
                    DiagnosticList(
                        title: localizedString(theme.language, english: "Evidence", chinese: "证据", italian: "Evidenza", french: "Preuve", spanish: "Evidencia"),
                        systemImage: "doc.text.magnifyingglass",
                        items: evidence.prefix(4).map(\.message)
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(startRequirements) { requirement in
                        TaowaRequirementRow(requirement: requirement)
                    }
                    if let startHintText {
                        Text(startHintText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    GlassButton(systemImage: "play.fill", title: localizedString(theme.language, english: "Start Multiplayer", chinese: "启动联机", italian: "Avvia multiplayer", french: "Démarrer", spanish: "Iniciar multijugador"), prominent: true) {
                        Task { await startSession() }
                    }
                    .disabled(isWorking || !canStartTunnel)
                    if let session = runningSession {
                        GlassButton(systemImage: "stop.fill", title: localizedString(theme.language, english: "Stop", chinese: "停止", italian: "Ferma", french: "Arrêter", spanish: "Detener")) {
                            Task { await stopSession(session) }
                        }
                        .disabled(isWorking)
                    }
                    GlassButton(systemImage: "clock.arrow.circlepath", title: localizedString(theme.language, english: "Clear History", chinese: "清理历史", italian: "Pulisci cronologia", french: "Effacer historique", spanish: "Limpiar historial")) {
                        Task { await clearHistory() }
                    }
                    .disabled(isWorking)
                }
            }
        }
    }

    private func sessionPanel(_ session: CoreTaowaSession) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PanelHeader(
                                title: localizedString(theme.language, english: "Connection Address", chinese: "连接地址", italian: "Indirizzo", french: "Adresse", spanish: "Dirección"),
                                systemImage: "link"
                            )
                            StatusBadge(title: session.status, style: badgeStyle(for: session.status))
                        }
                        Text(session.remoteAddress)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        MetadataLine(items: [
                            "local \(session.localPort)",
                            "remote \(session.remotePort)",
                            "pid \(session.processId.map(String.init) ?? "-")"
                        ])
                        HStack(spacing: 8) {
                            GlassButton(systemImage: "doc.on.doc", title: localizedString(theme.language, english: "Copy Address", chinese: "复制地址", italian: "Copia indirizzo", french: "Copier adresse", spanish: "Copiar dirección")) {
                                copy(session.remoteAddress, message: localizedString(theme.language, english: "Connection address copied.", chinese: "连接地址已复制。", italian: "Indirizzo copiato.", french: "Adresse copiée.", spanish: "Dirección copiada."))
                            }
                            GlassButton(systemImage: "doc.text.magnifyingglass", title: localizedString(theme.language, english: "Load Log", chinese: "读取日志", italian: "Carica log", french: "Charger journal", spanish: "Cargar registro")) {
                                Task { await loadLog(session) }
                            }
                            GlassButton(systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Refresh Session", chinese: "刷新会话", italian: "Aggiorna sessione", french: "Actualiser session", spanish: "Actualizar sesión")) {
                                Task { await reloadSession(session) }
                            }
                            if !session.frpcLogPath.isEmpty {
                                GlassButton(systemImage: "arrow.up.forward.app", title: localizedString(theme.language, english: "Open Log File", chinese: "打开日志文件", italian: "Apri log", french: "Ouvrir journal", spanish: "Abrir registro")) {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: session.frpcLogPath))
                                }
                            }
                        }
                        if let health {
                            MetadataLine(items: [
                                health.localPortReachable ? "local reachable" : "local unreachable",
                                health.processManaged ? "managed" : "not managed",
                                health.stale ? "stale" : "current"
                            ])
                        }
                    }
                    Spacer(minLength: 0)
                    QRCodeImage(value: session.remoteAddress)
                        .frame(width: 150, height: 150)
                        .accessibilityLabel(localizedString(theme.language, english: "QR code for connection address", chinese: "连接地址二维码", italian: "Codice QR indirizzo", french: "QR code adresse", spanish: "Código QR de dirección"))
                }

                if !logTail.isEmpty {
                    ScrollView {
                        Text(logTail)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .task(id: session.sessionId) {
            await loadHealth(session)
        }
    }

    private var sessionHistoryPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Session History", chinese: "会话历史", italian: "Cronologia sessioni", french: "Historique sessions", spanish: "Historial de sesiones"),
                        systemImage: "clock.arrow.circlepath"
                    )
                    Spacer()
                    StatusBadge(title: "\(relevantSessions.count)", style: .neutral)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(relevantSessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(8)) { session in
                        TaowaSessionHistoryRow(
                            session: session,
                            isSelected: session.sessionId == displaySession?.sessionId,
                            onSelect: {
                                selectedSessionId = session.sessionId
                                if session.status == "failed" || session.status == "stopped" {
                                    Task { await loadLog(session) }
                                } else {
                                    Task { await loadHealth(session) }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func diagnosticsPanel(_ diagnostics: [CoreDiagnostic]) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Diagnostics", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico"),
                    systemImage: "stethoscope"
                )
                ForEach(diagnostics, id: \.code) { diagnostic in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(diagnostic.title)
                                .font(.callout.weight(.semibold))
                            StatusBadge(title: diagnostic.severity, style: diagnostic.severity == "warning" ? .warning : .error)
                        }
                        Text(diagnostic.userSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        MetadataLine(items: [
                            diagnostic.code,
                            diagnostic.phase,
                            diagnostic.actionLabel
                        ])
                        if !diagnostic.evidence.isEmpty {
                            DiagnosticList(
                                title: localizedString(theme.language, english: "Evidence", chinese: "证据", italian: "Evidenza", french: "Preuve", spanish: "Evidencia"),
                                systemImage: "list.bullet.clipboard",
                                items: diagnostic.evidence.prefix(4).map { "\($0.key): \($0.value)" }
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let errorText {
            Text(errorText)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        } else if !copyStatus.isEmpty {
            Text(copyStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if !statusText.isEmpty {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    private func badgeStyle(for status: String) -> StatusBadge.Style {
        switch status {
        case "running":
            return .running
        case "stopped":
            return .neutral
        case "failed":
            return .error
        default:
            return .warning
        }
    }

    private func standardizedPath(_ value: String) -> String {
        URL(fileURLWithPath: value).standardizedFileURL.path
    }
}

private struct TaowaProfileDraft: Equatable {
    var displayName = ""
    var serverAddr = ""
    var serverPort = "7000"
    var token = ""
    var remotePort = "25565"
    var frpcPath = ""
    var enabled = true
    var hasExistingToken = false

    init() {}

    init(profile: CoreTaowaFrpProfile) {
        displayName = profile.displayName
        serverAddr = profile.serverAddr
        serverPort = String(profile.serverPort)
        token = ""
        remotePort = String(profile.remotePort)
        frpcPath = profile.frpcPath
        enabled = profile.enabled
        hasExistingToken = profile.hasToken
    }

    func request(profileId: String?) -> CoreTaowaFrpProfileRequest? {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let addr = serverAddr.trimmingCharacters(in: .whitespacesAndNewlines)
        let frpc = frpcPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !addr.isEmpty,
              !frpc.isEmpty,
              let serverPortValue = Int(serverPort.trimmingCharacters(in: .whitespacesAndNewlines)),
              let remotePortValue = Int(remotePort.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(serverPortValue),
              (1...65535).contains(remotePortValue)
        else {
            return nil
        }
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return CoreTaowaFrpProfileRequest(
            profileId: profileId,
            displayName: name,
            serverAddr: addr,
            serverPort: serverPortValue,
            token: trimmedToken.isEmpty ? nil : trimmedToken,
            remotePort: remotePortValue,
            protocolName: "tcp",
            frpcPath: frpc,
            enabled: enabled
        )
    }
}

private struct TaowaWorkflowStep: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let style: StatusBadge.Style
    let isReady: Bool
}

private struct TaowaStepCard: View {
    let step: TaowaWorkflowStep

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(step.style.color.opacity(0.18))
                Image(systemName: step.isReady ? "checkmark" : step.systemImage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(step.style.color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(step.style.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(step.style.color.opacity(step.isReady ? 0.26 : 0.14), lineWidth: 1)
        }
    }
}

private struct TaowaProfileCard: View {
    let profile: CoreTaowaFrpProfile
    let isSelected: Bool
    let hasActiveSession: Bool
    let onSelect: () -> Void
    let onCopyAddress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: profile.enabled ? "server.rack" : "pause.circle")
                    .foregroundStyle(style.color)
                Text(profile.displayName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(style.color)
                }
            }
            Text(profile.remoteAddress)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 6) {
                StatusBadge(title: profile.enabled ? "enabled" : "disabled", style: style)
                if profile.hasToken {
                    StatusBadge(title: "token", style: .neutral)
                }
                if hasActiveSession {
                    StatusBadge(title: "active", style: .running)
                }
                Spacer(minLength: 0)
                Button(action: onCopyAddress) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy remote address")
                .accessibilityLabel("Copy remote address")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color.opacity(isSelected ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style.color.opacity(isSelected ? 0.45 : 0.14), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onSelect)
    }

    private var style: StatusBadge.Style {
        if hasActiveSession {
            return .running
        }
        return profile.enabled ? .success : .warning
    }
}

private struct TaowaRequirement: Identifiable {
    enum State {
        case ready
        case warning
        case missing

        var systemImage: String {
            switch self {
            case .ready:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.circle.fill"
            case .missing:
                return "xmark.circle.fill"
            }
        }

        var style: StatusBadge.Style {
            switch self {
            case .ready:
                return .success
            case .warning:
                return .warning
            case .missing:
                return .error
            }
        }
    }

    let id: String
    let title: String
    let state: State
}

private struct TaowaRequirementRow: View {
    let requirement: TaowaRequirement

    var body: some View {
        Label {
            Text(requirement.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } icon: {
            Image(systemName: requirement.state.systemImage)
                .foregroundStyle(requirement.state.style.color)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TaowaProfileTestPanel: View {
    let test: CoreTaowaFrpProfileTestResponse
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    test.ok
                        ? localizedString(theme.language, english: "Profile test passed", chinese: "配置测试通过", italian: "Test profilo riuscito", french: "Test du profil réussi", spanish: "Prueba de perfil superada")
                        : localizedString(theme.language, english: "Profile test needs attention", chinese: "配置测试需要处理", italian: "Test profilo da controllare", french: "Test du profil à vérifier", spanish: "Prueba de perfil requiere atención"),
                    systemImage: test.ok ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(style.color)
                Spacer()
                StatusBadge(title: test.ok ? "ok" : localizedString(theme.language, english: "check failed", chinese: "检查失败", italian: "controllo fallito", french: "échec", spanish: "falló"), style: style)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                ForEach(test.checks) { check in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: check.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(check.ok ? StatusBadge.Style.success.color : StatusBadge.Style.error.color)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(check.name)
                                .font(.caption.weight(.semibold))
                            Text(check.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background((check.ok ? Color.green : Color.red).opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(10)
        .background(style.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style.color.opacity(0.18), lineWidth: 1)
        }
    }

    private var style: StatusBadge.Style {
        test.ok ? .success : .warning
    }
}

private struct TaowaSessionHistoryRow: View {
    let session: CoreTaowaSession
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(session.remoteAddress)
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    StatusBadge(title: session.status, style: style)
                }
                MetadataLine(items: [
                    "local \(session.localPort)",
                    "remote \(session.remotePort)",
                    session.updatedAt.formatted(date: .abbreviated, time: .shortened)
                ])
                if !session.diagnostics.isEmpty {
                    Text(session.diagnostics.first?.userSummary ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.color.opacity(isSelected ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style.color.opacity(isSelected ? 0.42 : 0.14), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var style: StatusBadge.Style {
        switch session.status {
        case "running":
            return .running
        case "failed":
            return .error
        case "stopped":
            return .neutral
        default:
            return .warning
        }
    }
}

private struct QRCodeImage: View {
    let value: String

    private static let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = makeImage() {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(10)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
        } else {
            ContentUnavailableView("QR", systemImage: "qrcode")
        }
    }

    private func makeImage() -> NSImage? {
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = Self.context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: transformed.extent.width, height: transformed.extent.height))
    }
}
