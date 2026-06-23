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
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
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
