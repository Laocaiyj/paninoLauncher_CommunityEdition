import AppKit
import SwiftUI

struct TaowaHeaderPanel: View {
    let isLoading: Bool
    let isWorking: Bool
    let errorText: String?
    let copyStatus: String
    let statusText: String
    let connectionStateTitle: String
    let connectionBadgeStyle: StatusBadge.Style

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}

struct TaowaWorkflowPanel: View {
    let workflowSteps: [TaowaWorkflowStep]

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}

struct TaowaProfilePanel: View {
    let profiles: [CoreTaowaFrpProfile]
    @Binding var selectedProfileId: String
    let editingProfileId: String?
    @Binding var profileDraft: TaowaProfileDraft
    let profileTest: CoreTaowaFrpProfileTestResponse?
    let isWorking: Bool
    let activeSessionForProfile: (String) -> CoreTaowaSession?
    let onRefresh: () -> Void
    let onNewProfile: () -> Void
    let onCopyAddress: (String, String) -> Void
    let onChooseFrpc: () -> Void
    let onSave: () -> Void
    let onTest: (String) -> Void
    let onDelete: (String) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "FRP Profile", chinese: "FRP 配置", italian: "Profilo FRP", french: "Profil FRP", spanish: "Perfil FRP"),
                        systemImage: "server.rack"
                    )
                    Spacer()
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: onRefresh)
                        .disabled(isWorking)
                    GlassButton(systemImage: "plus", title: localizedString(theme.language, english: "New", chinese: "新建", italian: "Nuovo", french: "Nouveau", spanish: "Nuevo"), action: onNewProfile)
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
                                    onCopyAddress(
                                        profile.remoteAddress,
                                        localizedString(theme.language, english: "Profile remote address copied.", chinese: "配置远程地址已复制。", italian: "Indirizzo remoto copiato.", french: "Adresse distante copiée.", spanish: "Dirección remota copiada.")
                                    )
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
                            GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Choose", chinese: "选择", italian: "Scegli", french: "Choisir", spanish: "Elegir"), action: onChooseFrpc)
                        }
                    }
                    SettingsRow(title: localizedString(theme.language, english: "Enabled", chinese: "启用", italian: "Abilitato", french: "Activé", spanish: "Activado"), systemImage: "checkmark.circle") {
                        Toggle("", isOn: $profileDraft.enabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                HStack(spacing: 8) {
                    GlassButton(systemImage: "checkmark", title: localizedString(theme.language, english: "Save", chinese: "保存", italian: "Salva", french: "Enregistrer", spanish: "Guardar"), prominent: true, action: onSave)
                        .disabled(isWorking)
                    if let editingProfileId {
                        GlassButton(systemImage: "checkmark.shield", title: localizedString(theme.language, english: "Test", chinese: "测试", italian: "Test", french: "Tester", spanish: "Probar")) {
                            onTest(editingProfileId)
                        }
                        .disabled(isWorking)
                        GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language)) {
                            onDelete(editingProfileId)
                        }
                        .disabled(isWorking || activeSessionForProfile(editingProfileId) != nil)
                    }
                }
            }
        }
    }
}

struct TaowaTunnelPanel: View {
    let instance: GameInstance
    @Binding var localPortText: String
    let detection: CoreTaowaLanPortDetection?
    let startRequirements: [TaowaRequirement]
    let startHintText: String?
    let isWorking: Bool
    let hasParsedLocalPort: Bool
    let canStartTunnel: Bool
    let runningSession: CoreTaowaSession?
    let onDetectLanPort: () -> Void
    let onValidatePort: () -> Void
    let onStartSession: () -> Void
    let onStopSession: (CoreTaowaSession) -> Void
    let onClearHistory: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
                        GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Detect", chinese: "检测", italian: "Rileva", french: "Détecter", spanish: "Detectar"), action: onDetectLanPort)
                            .disabled(isWorking || instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        GlassButton(systemImage: "checkmark.seal", title: localizedString(theme.language, english: "Validate", chinese: "校验", italian: "Valida", french: "Valider", spanish: "Validar"), action: onValidatePort)
                            .disabled(isWorking || !hasParsedLocalPort)
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
                    GlassButton(systemImage: "play.fill", title: localizedString(theme.language, english: "Start Multiplayer", chinese: "启动联机", italian: "Avvia multiplayer", french: "Démarrer", spanish: "Iniciar multijugador"), prominent: true, action: onStartSession)
                        .disabled(isWorking || !canStartTunnel)
                    if let runningSession {
                        GlassButton(systemImage: "stop.fill", title: localizedString(theme.language, english: "Stop", chinese: "停止", italian: "Ferma", french: "Arrêter", spanish: "Detener")) {
                            onStopSession(runningSession)
                        }
                        .disabled(isWorking)
                    }
                    GlassButton(systemImage: "clock.arrow.circlepath", title: localizedString(theme.language, english: "Clear History", chinese: "清理历史", italian: "Pulisci cronologia", french: "Effacer historique", spanish: "Limpiar historial"), action: onClearHistory)
                        .disabled(isWorking)
                }
            }
        }
    }
}

struct TaowaSessionPanel: View {
    let session: CoreTaowaSession
    let health: CoreTaowaSessionHealthResponse?
    let logTail: String
    let onCopyAddress: (String, String) -> Void
    let onLoadLog: (CoreTaowaSession) -> Void
    let onReloadSession: (CoreTaowaSession) -> Void
    let onLoadHealth: (CoreTaowaSession) async -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PanelHeader(
                                title: localizedString(theme.language, english: "Connection Address", chinese: "连接地址", italian: "Indirizzo", french: "Adresse", spanish: "Dirección"),
                                systemImage: "link"
                            )
                            StatusBadge(title: session.status, style: TaowaSessionStatusStyle.badgeStyle(for: session.status))
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
                                onCopyAddress(
                                    session.remoteAddress,
                                    localizedString(theme.language, english: "Connection address copied.", chinese: "连接地址已复制。", italian: "Indirizzo copiato.", french: "Adresse copiée.", spanish: "Dirección copiada.")
                                )
                            }
                            GlassButton(systemImage: "doc.text.magnifyingglass", title: localizedString(theme.language, english: "Load Log", chinese: "读取日志", italian: "Carica log", french: "Charger journal", spanish: "Cargar registro")) {
                                onLoadLog(session)
                            }
                            GlassButton(systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Refresh Session", chinese: "刷新会话", italian: "Aggiorna sessione", french: "Actualiser session", spanish: "Actualizar sesión")) {
                                onReloadSession(session)
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
            await onLoadHealth(session)
        }
    }
}

struct TaowaSessionHistoryPanel: View {
    let sessions: [CoreTaowaSession]
    let selectedSessionId: String?
    let onSelect: (CoreTaowaSession) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Session History", chinese: "会话历史", italian: "Cronologia sessioni", french: "Historique sessions", spanish: "Historial de sesiones"),
                        systemImage: "clock.arrow.circlepath"
                    )
                    Spacer()
                    StatusBadge(title: "\(sessions.count)", style: .neutral)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(sessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(8)) { session in
                        TaowaSessionHistoryRow(
                            session: session,
                            isSelected: session.sessionId == selectedSessionId,
                            onSelect: {
                                onSelect(session)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct TaowaDiagnosticsPanel: View {
    let diagnostics: [CoreDiagnostic]

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}
