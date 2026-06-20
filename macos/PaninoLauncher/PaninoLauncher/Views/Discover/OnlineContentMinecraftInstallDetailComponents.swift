import SwiftUI

struct MinecraftInstallHeaderPanel: View {
    let version: MinecraftVersionInfo
    let onBack: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                HStack(spacing: 10) {
                    GlassButton(
                        systemImage: "chevron.left",
                        title: localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Atrás"),
                        action: onBack
                    )
                    PanelHeader(
                        title: localizedString(theme.language, english: "Install Minecraft \(version.id)", chinese: "安装 Minecraft \(version.id)", italian: "Installa Minecraft \(version.id)", french: "Installer Minecraft \(version.id)", spanish: "Instalar Minecraft \(version.id)"),
                        systemImage: "arrow.down.circle"
                    )
                    Spacer()
                    MetadataLine(items: [version.kind.title(language: theme.language)], font: .caption.weight(.semibold))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    MinecraftInstallMetricCard(
                        title: localizedString(theme.language, english: "Released", chinese: "发布时间", italian: "Rilascio", french: "Sortie", spanish: "Publicado"),
                        value: version.releasedAt
                    )
                    MinecraftInstallMetricCard(title: "Java", value: version.javaRequirement)
                    MinecraftInstallMetricCard(
                        title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"),
                        value: discoverVisibleDownloadState(version, language: theme.language) ?? "-"
                    )
                    MinecraftInstallMetricCard(
                        title: localizedString(theme.language, english: "Verify", chinese: "校验", italian: "Verifica", french: "Vérifier", spanish: "Verificar"),
                        value: version.verificationState.localizedVersionState(theme.language)
                    )
                }
            }
        }
    }
}

struct MinecraftInstallInstancePanel: View {
    @Binding var instanceName: String
    let targetDirectoryLabel: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .panel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Local Instance", chinese: "本地实例", italian: "Istanza locale", french: "Instance locale", spanish: "Instancia local"),
                    systemImage: "folder.badge.plus"
                )
                PaninoTextInput(
                    localizedString(theme.language, english: "Instance name", chinese: "实例名称", italian: "Nome istanza", french: "Nom de l'instance", spanish: "Nombre de instancia"),
                    text: $instanceName
                )
                Text(localizedString(
                    theme.language,
                    english: "Folder: \(targetDirectoryLabel)",
                    chinese: "目录：\(targetDirectoryLabel)",
                    italian: "Cartella: \(targetDirectoryLabel)",
                    french: "Dossier : \(targetDirectoryLabel)",
                    spanish: "Carpeta: \(targetDirectoryLabel)"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            }
        }
    }
}
