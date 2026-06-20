import SwiftUI

struct ErrorDetailContext: Equatable {
    let title: String
    let userSummary: String
    let technicalDetail: String
    let causes: [String]
    let actions: [String]

    var copyText: String {
        """
        \(title)

        User summary:
        \(userSummary)

        Technical details:
        \(technicalDetail)

        Possible causes:
        \(causes.joined(separator: "\n"))

        Recommended actions:
        \(actions.joined(separator: "\n"))
        """
    }

    var minimumReproText: String {
        """
        Panino minimal repro
        title=\(title)
        summary=\(userSummary)

        technical:
        \(technicalDetail)

        actions_tried:
        \(actions.joined(separator: "\n"))
        """
    }
}

struct ErrorDetailPanel: View {
    let context: ErrorDetailContext
    let onCopy: (ErrorDetailContext) -> Void
    let onCopyRepro: (ErrorDetailContext) -> Void
    let onExportDiagnostics: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                HStack {
                    PanelHeader(title: context.title, systemImage: "exclamationmark.triangle")
                    Spacer()
                    GlassButton(systemImage: "doc.on.doc", title: localizedString(theme.language, english: "Copy Details", chinese: "复制详情", italian: "Copia dettagli", french: "Copier détails", spanish: "Copiar detalles")) {
                        onCopy(context)
                    }
                    GlassButton(systemImage: "doc.badge.gearshape", title: localizedString(theme.language, english: "Copy Repro", chinese: "复制复现", italian: "Copia repro", french: "Copier repro", spanish: "Copiar repro")) {
                        onCopyRepro(context)
                    }
                    GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostic", spanish: "Exportar diagnóstico"), action: onExportDiagnostics)
                }

                SettingsRow(title: localizedString(theme.language, english: "For You", chinese: "用户说明", italian: "Per te", french: "Pour vous", spanish: "Para ti"), systemImage: "person") {
                    Text(context.userSummary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }

                DiagnosticList(
                    title: localizedString(theme.language, english: "Recommended Actions", chinese: "建议操作", italian: "Azioni consigliate", french: "Actions recommandées", spanish: "Acciones recomendadas"),
                    systemImage: "checklist",
                    items: context.actions
                )
                DiagnosticList(
                    title: localizedString(theme.language, english: "Possible Causes", chinese: "可能原因", italian: "Cause possibili", french: "Causes possibles", spanish: "Causas posibles"),
                    systemImage: "questionmark.circle",
                    items: context.causes
                )

                SettingsRow(title: localizedString(theme.language, english: "Technical", chinese: "技术详情", italian: "Tecnico", french: "Technique", spanish: "Técnico"), systemImage: "curlybraces") {
                    Text(context.technicalDetail)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(5)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct DiagnosticList: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        SettingsRow(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Label(item, systemImage: "smallcircle.filled.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }
}

struct AccountCard: View {
    let accountState: AccountConnectionState

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusStyle.color.opacity(0.18))
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusStyle.color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppText.microsoftAccount.localized(theme.language))
                        .font(.headline)
                    Text(accountState.localizedTitle(theme.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer()

                StatusBadge(title: statusTitle, style: statusStyle)
            }
        }
    }

    private var statusTitle: String {
        switch accountState {
        case .signedIn:
            return AppText.signedIn.localized(theme.language)
        case .restoring:
            return AppText.restoring.localized(theme.language)
        case .waitingForDeviceCode:
            return AppText.waiting.localized(theme.language)
        case .failed:
            return AppText.error.localized(theme.language)
        case .signedOut:
            return AppText.signedOut.localized(theme.language)
        }
    }

    private var statusStyle: StatusBadge.Style {
        switch accountState {
        case .signedIn:
            return .success
        case .restoring, .waitingForDeviceCode:
            return .running
        case .failed:
            return .error
        case .signedOut:
            return .neutral
        }
    }

    private var statusIcon: String {
        switch accountState {
        case .signedIn:
            return "person.crop.circle.fill.badge.checkmark"
        case .restoring, .waitingForDeviceCode:
            return "person.crop.circle.badge.clock"
        case .failed:
            return "person.crop.circle.badge.exclamationmark"
        case .signedOut:
            return "person.crop.circle"
        }
    }
}

struct InstanceCard: View {
    let title: String
    let subtitle: String
    let status: StatusBadge.Style
    let icon: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                        .fill(status.color.opacity(0.16))
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(status.color)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer()

                StatusBadge(title: statusTitle, style: status)
            }
        }
    }

    private var statusTitle: String {
        switch status {
        case .success:
            return AppText.ready.localized(theme.language)
        case .warning:
            return AppText.attention.localized(theme.language)
        case .error:
            return AppText.failed.localized(theme.language)
        case .download:
            return AppText.downloading.localized(theme.language)
        case .running:
            return AppText.running.localized(theme.language)
        case .neutral:
            return AppText.idle.localized(theme.language)
        }
    }
}

struct DeviceCodePanel: View {
    let session: DeviceCodeSession
    let onCancel: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(session.userCode)
                    .font(.system(.title3, design: .monospaced).bold())
                    .textSelection(.enabled)

                Link(AppText.openMicrosoft.localized(theme.language), destination: session.verificationURI)

                GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
            }

            Text(session.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card))
    }
}
