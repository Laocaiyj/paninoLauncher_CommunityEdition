import SwiftUI

struct PackDoctorPanel: View {
    enum Presentation {
        case panel
        case compact
    }

    let report: CoreCompatibilityReport?
    let performanceSummary: CorePerformanceSummary?
    let diagnostics: [CoreDiagnostic]
    let isWorking: Bool
    let statusText: String
    var presentation: Presentation = .panel
    let onRefresh: () -> Void
    let onPrimaryAction: () -> Void
    let onOpenDiagnostics: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        switch presentation {
        case .panel:
            panelBody
        case .compact:
            compactBody
        }
    }

    private var panelBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                Spacer()
                if isWorking {
                    ProgressView()
                        .scaleEffect(0.72)
                }
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help(localizedString(theme.language, english: "Refresh Pack Doctor", chinese: "刷新 Pack Doctor", italian: "Aggiorna Pack Doctor", french: "Actualiser Pack Doctor", spanish: "Actualizar Pack Doctor"))
            }

            Text(detailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let diagnostic = primaryDiagnostic {
                HStack(spacing: 8) {
                    Label(diagnostic.code, systemImage: "stethoscope")
                        .font(.caption.weight(.semibold))
                    Text(diagnostic.actionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                Button(primaryActionTitle) {
                    onPrimaryAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(primaryActionDisabled)

                Button(localizedString(theme.language, english: "Diagnostics", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico")) {
                    onOpenDiagnostics()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .paninoGlassCard(
            isSelected: report?.status == "blocked" || report?.status == "warning",
            level: .floatingChrome,
            cornerRadius: PaninoTokens.Radius.card,
            tint: statusColor,
            showsShadow: false
        )
        .accessibilityElement(children: .contain)
    }

    private var compactBody: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                compactTitle
                compactDetail
                Spacer(minLength: 8)
                compactActions
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    compactTitle
                    Spacer(minLength: 8)
                    compactActions
                }
                compactDetail
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .paninoGlassCard(
            isSelected: report?.status == "blocked" || report?.status == "warning",
            level: .floatingChrome,
            cornerRadius: PaninoTokens.Radius.card,
            tint: statusColor,
            showsShadow: false
        )
        .accessibilityElement(children: .contain)
    }

    private var compactTitle: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .allowsTightening(true)
    }

    private var compactDetail: some View {
        Text(detailText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
    }

    private var compactActions: some View {
        HStack(spacing: 6) {
            if isWorking {
                ProgressView()
                    .scaleEffect(0.64)
            }

            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(localizedString(theme.language, english: "Refresh Pack Doctor", chinese: "刷新 Pack Doctor", italian: "Aggiorna Pack Doctor", french: "Actualiser Pack Doctor", spanish: "Actualizar Pack Doctor"))

            Button {
                onOpenDiagnostics()
            } label: {
                Text(localizedString(theme.language, english: "Diagnose", chinese: "诊断", italian: "Diagnosi", french: "Diagnostic", spanish: "Diagnóstico"))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 26)
            }
            .buttonStyle(.plain)
        }
    }

    private var title: String {
        switch report?.status {
        case "blocked":
            return localizedString(theme.language, english: "Pack Doctor Blocked", chinese: "Pack Doctor 已阻塞", italian: "Pack Doctor bloccato", french: "Pack Doctor bloqué", spanish: "Pack Doctor bloqueado")
        case "unknown":
            return localizedString(theme.language, english: "Pack Doctor Needs Data", chinese: "Pack Doctor 需要数据", italian: "Pack Doctor richiede dati", french: "Pack Doctor requiert des données", spanish: "Pack Doctor necesita datos")
        case "warning":
            return localizedString(theme.language, english: "Pack Doctor Needs Review", chinese: "Pack Doctor 需要检查", italian: "Pack Doctor da controllare", french: "Pack Doctor à vérifier", spanish: "Pack Doctor requiere revisión")
        case "compatible":
            return localizedString(theme.language, english: "Pack Doctor Ready", chinese: "Pack Doctor 就绪", italian: "Pack Doctor pronto", french: "Pack Doctor prêt", spanish: "Pack Doctor listo")
        default:
            return localizedString(theme.language, english: "Pack Doctor", chinese: "Pack Doctor", italian: "Pack Doctor", french: "Pack Doctor", spanish: "Pack Doctor")
        }
    }

    private var detailText: String {
        if let summary = report?.summary, !summary.isEmpty {
            return summary
        }
        if !statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return statusText
        }
        if let performanceSummary {
            return "\(performanceSummary.title) · \(performanceSummary.confidence ?? "estimated")"
        }
        return localizedString(theme.language, english: "Waiting for Core report.", chinese: "等待 Core 报告。", italian: "In attesa del report Core.", french: "En attente du rapport Core.", spanish: "Esperando informe de Core.")
    }

    private var primaryDiagnostic: CoreDiagnostic? {
        report?.primaryDiagnostic ?? diagnostics.first
    }

    private var primaryActionTitle: String {
        primaryDiagnostic?.actionLabel
            ?? performanceSummary?.primaryAction.title
            ?? localizedString(theme.language, english: "Refresh", chinese: "刷新", italian: "Aggiorna", french: "Actualiser", spanish: "Actualizar")
    }

    private var primaryActionDisabled: Bool {
        primaryDiagnostic == nil && performanceSummary == nil && report == nil
    }

    private var statusColor: Color {
        switch report?.status {
        case "blocked":
            return .red
        case "warning":
            return .orange
        case "unknown":
            return .secondary
        case "compatible":
            return .green
        default:
            return .primary
        }
    }
}
