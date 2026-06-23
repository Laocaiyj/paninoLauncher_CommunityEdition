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
