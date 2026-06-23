import SwiftUI

struct InstanceVersionRuntimeHeader: View {
    let versionStateTitle: String
    let versionBadgeStyle: StatusBadge.Style
    let canApplyVersion: Bool
    let canRepairVersion: Bool
    let onBack: () -> Void
    let onApply: () -> Void
    let onRepair: () -> Void
    let onDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 12) {
            GlassButton(
                systemImage: "chevron.left",
                title: localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Atrás"),
                action: onBack
            )
            PanelHeader(
                title: localizedString(theme.language, english: "Version Runtime", chinese: "版本运行设置", italian: "Runtime versione", french: "Runtime version", spanish: "Runtime de versión"),
                systemImage: "slider.horizontal.3"
            )
            StatusBadge(title: versionStateTitle, style: versionBadgeStyle)
            Spacer()
            if canApplyVersion {
                GlassButton(
                    systemImage: "checkmark.circle",
                    title: localizedString(theme.language, english: "Apply to Configuration", chinese: "应用到配置", italian: "Applica", french: "Appliquer", spanish: "Aplicar"),
                    prominent: true,
                    action: onApply
                )
            }
            GlassButton(
                systemImage: "checkmark.seal",
                title: localizedString(theme.language, english: "Repair Files", chinese: "修复文件", italian: "Ripara file", french: "Réparer fichiers", spanish: "Reparar archivos"),
                prominent: true,
                action: onRepair
            )
            .disabled(!canRepairVersion)
            GlassButton(
                systemImage: "arrow.down.app",
                title: localizedString(theme.language, english: "Get Versions", chinese: "获取版本", italian: "Ottieni versioni", french: "Obtenir versions", spanish: "Obtener versiones"),
                action: onDiscover
            )
        }
    }
}
