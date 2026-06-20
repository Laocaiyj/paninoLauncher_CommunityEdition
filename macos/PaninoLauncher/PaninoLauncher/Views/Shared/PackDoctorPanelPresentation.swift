import SwiftUI

extension PackDoctorPanel {
    var title: String {
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

    var detailText: String {
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

    var primaryDiagnostic: CoreDiagnostic? {
        report?.primaryDiagnostic ?? diagnostics.first
    }

    var primaryActionTitle: String {
        primaryDiagnostic?.actionLabel
            ?? performanceSummary?.primaryAction.title
            ?? localizedString(theme.language, english: "Refresh", chinese: "刷新", italian: "Aggiorna", french: "Actualiser", spanish: "Actualizar")
    }

    var primaryActionDisabled: Bool {
        primaryDiagnostic == nil && performanceSummary == nil && report == nil
    }

    var statusColor: Color {
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

    var needsProminentSurface: Bool {
        report?.status == "blocked" || report?.status == "warning"
    }
}
