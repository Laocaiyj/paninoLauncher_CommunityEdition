import SwiftUI

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
