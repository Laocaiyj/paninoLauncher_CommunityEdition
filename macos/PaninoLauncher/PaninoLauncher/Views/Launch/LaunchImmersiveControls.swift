import SwiftUI

struct LaunchImmersiveControls: View {
    let hasInstalledInstances: Bool
    let primaryTitle: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let onPrimaryAction: () -> Void
    let onCancel: () -> Void
    let openDetails: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { controls }
            VStack(alignment: .trailing, spacing: 10) { controls }
        }
        .padding(8)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 10, tint: theme.semanticSelectionColor, showsShadow: true)
    }

    @ViewBuilder
    private var controls: some View {
        if hasInstalledInstances {
            LaunchHeroTextButton(
                title: primaryTitle,
                prominent: true,
                minWidth: 132,
                minHeight: 48,
                action: onPrimaryAction
            )
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(primaryDisabled)

            LaunchHeroTextButton(
                title: localizedString(theme.language, english: "Details", chinese: "详情", italian: "Dettagli", french: "Détails", spanish: "Detalles"),
                minWidth: 104,
                minHeight: 48,
                action: openDetails
            )

            if canCancel {
                GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
            }
        } else {
            LaunchHeroTextButton(
                title: localizedString(theme.language, english: "Get", chinese: "获取", italian: "Ottieni", french: "Obtenir", spanish: "Obtener"),
                prominent: true,
                minWidth: 104,
                minHeight: 48,
                action: openDiscover
            )
        }
    }
}
