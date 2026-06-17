import SwiftUI

enum LaunchPreflightState {
    case ready
    case needsFix
    case optional

    var badgeStyle: StatusBadge.Style {
        switch self {
        case .ready:
            return .success
        case .needsFix:
            return .warning
        case .optional:
            return .neutral
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .ready:
            return localizedString(language, english: "Ready", chinese: "可启动", italian: "Pronto", french: "Prêt", spanish: "Listo")
        case .needsFix:
            return localizedString(language, english: "Fix", chinese: "需修复", italian: "Ripara", french: "À corriger", spanish: "Reparar")
        case .optional:
            return localizedString(language, english: "Optional", chinese: "可忽略", italian: "Opzionale", french: "Optionnel", spanish: "Opcional")
        }
    }
}

struct LaunchPreflightItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let state: LaunchPreflightState
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        id: String,
        title: String,
        detail: String,
        state: LaunchPreflightState,
        actionTitle: String?,
        action: (() -> Void)?
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.actionTitle = actionTitle
        self.action = action
    }
}

struct LaunchPreflightChecklist: View {
    let items: [LaunchPreflightItem]
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Pre-launch Check", chinese: "启动前检查", italian: "Controllo pre-avvio", french: "Vérification avant lancement", spanish: "Comprobación previa"),
                    systemImage: "checklist.checked"
                )

                ForEach(items) { item in
                    LaunchPreflightRow(item: item)
                }
            }
        }
    }
}

private struct LaunchPreflightRow: View {
    let item: LaunchPreflightItem
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                rowStatus
                    .frame(width: 90, alignment: .leading)
                rowText
                Spacer(minLength: 8)
                rowAction
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    rowStatus
                    Spacer(minLength: 8)
                    rowAction
                }
                rowText
            }
        }
        .padding(10)
        .paninoGlassCard(isSelected: item.state == .needsFix, level: item.state == .needsFix ? .elevatedPanel : .panel, cornerRadius: 8, tint: item.state.badgeStyle.color, showsShadow: item.state == .needsFix)
    }

    private var rowStatus: some View {
        StatusBadge(title: item.state.title(language: theme.language), style: item.state.badgeStyle)
    }

    private var rowText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private var rowAction: some View {
        if let actionTitle = item.actionTitle, let action = item.action {
            GlassButton(systemImage: "arrow.right.circle", title: actionTitle, action: action)
                .frame(minWidth: 92, alignment: .trailing)
        }
    }
}
