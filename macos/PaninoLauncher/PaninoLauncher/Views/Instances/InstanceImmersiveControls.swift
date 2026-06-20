import SwiftUI

struct InstanceImmersiveControls: View {
    let instance: GameInstance?
    let canSubmitTask: Bool
    let isMutatingInstance: Bool
    let launch: (GameInstance) -> Void
    let openProperties: (GameInstance) -> Void
    let openFolder: (GameInstance) -> Void
    let restoreArchive: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { controls }
            VStack(alignment: .trailing, spacing: 10) { controls }
        }
        .padding(8)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 10, tint: instance?.coverTintColor ?? theme.semanticSelectionColor, showsShadow: true)
    }

    @ViewBuilder
    private var controls: some View {
        if let instance {
            GlassButton(systemImage: "play.fill", title: AppText.launch.localized(theme.language), prominent: true) {
                launch(instance)
            }
            .disabled(!canSubmitTask || !GameConfigurationCapabilities.capabilities(for: instance).canLaunch)

            GlassButton(systemImage: "slider.horizontal.3", title: localizedString(theme.language, english: "Properties", chinese: "属性", italian: "Proprietà", french: "Propriétés", spanish: "Propiedades")) {
                openProperties(instance)
            }

            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                openFolder(instance)
            }
        } else {
            GlassButton(systemImage: "arrow.down.circle", title: localizedString(theme.language, english: "Get", chinese: "获取", italian: "Ottieni", french: "Obtenir", spanish: "Obtener"), prominent: true, action: openDiscover)
        }

        GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Restore Archive", chinese: "恢复归档", italian: "Ripristina archivio", french: "Restaurer archive", spanish: "Restaurar archivo"), action: restoreArchive)
            .disabled(isMutatingInstance)
    }
}
