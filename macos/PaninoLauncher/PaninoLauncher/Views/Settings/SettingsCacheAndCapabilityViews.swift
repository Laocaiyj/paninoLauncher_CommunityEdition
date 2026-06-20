import SwiftUI

struct CacheSummaryTile: View {
    let summary: CacheScopeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(summary.sizeText)
                .font(.callout.weight(.semibold).monospacedDigit())
            Text(summary.path)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

enum SettingCapability {
    case available
    case requiresCoreRestart
    case advancedOnly
    case notImplemented
}

struct CapabilityNote: View {
    let capability: SettingCapability
    var detail: String? = nil

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        if let message = displayMessage, !message.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                if capability != .available {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(capability == .available ? .secondary : indicatorColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var displayMessage: String? {
        switch capability {
        case .available:
            return detail
        case .requiresCoreRestart:
            let restart = localizedString(
                theme.language,
                english: "Restart Core to apply this change.",
                chinese: "重启 Core 后生效。",
                italian: "Riavvia Core per applicare la modifica.",
                french: "Redémarrez Core pour appliquer ce changement.",
                spanish: "Reinicia Core para aplicar este cambio."
            )
            if let detail, !detail.isEmpty {
                return "\(restart) \(detail)"
            }
            return restart
        case .advancedOnly:
            return detail ?? localizedString(
                theme.language,
                english: "Visible when advanced controls are enabled.",
                chinese: "启用高级控制后显示。",
                italian: "Visibile quando i controlli avanzati sono attivi.",
                french: "Visible lorsque les contrôles avancés sont activés.",
                spanish: "Visible cuando los controles avanzados están activos."
            )
        case .notImplemented:
            return detail
        }
    }

    private var indicatorColor: Color {
        switch capability {
        case .available:
            return .secondary
        case .requiresCoreRestart:
            return .orange
        case .advancedOnly:
            return .blue
        case .notImplemented:
            return .secondary
        }
    }
}
