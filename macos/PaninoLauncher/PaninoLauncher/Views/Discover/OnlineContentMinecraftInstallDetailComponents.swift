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

struct MinecraftInstallLoaderPanel: View {
    @Binding var loader: LoaderKind?
    @Binding var loaderVersion: String?

    let compatibleLoaders: [LoaderKind]
    let loaderOptions: [LoaderCompatibilityOption]
    let versionOptionsStatus: String
    let versionMenuLimit: Int
    let choiceState: (LoaderKind?) -> InstallChoicePreflightState
    let onSelectLoader: (LoaderKind?) -> Void
    let notice: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .panel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Loader", chinese: "加载器", italian: "Loader", french: "Loader", spanish: "Loader"),
                    systemImage: "puzzlepiece.extension"
                )
                HStack(spacing: 8) {
                    MinecraftInstallChoiceButton(
                        title: "Vanilla",
                        isSelected: loader == nil,
                        disabled: false,
                        state: choiceState(nil),
                        action: { onSelectLoader(nil) }
                    )
                    ForEach(LoaderKind.allCases) { kind in
                        MinecraftInstallChoiceButton(
                            title: kind.title,
                            isSelected: loader == kind,
                            disabled: !compatibleLoaders.contains(kind),
                            state: choiceState(kind),
                            action: { onSelectLoader(kind) }
                        )
                    }
                }
                versionPicker

                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var selectedLoaderOption: LoaderCompatibilityOption? {
        guard let loader else { return nil }
        return loaderOptions.first { $0.kind == loader }
    }

    private var selectedLoaderVersions: [LoaderMetadata] {
        selectedLoaderOption?.versions ?? []
    }

    private var visibleSelectedLoaderVersions: [LoaderMetadata] {
        Array(selectedLoaderVersions.prefix(versionMenuLimit))
    }

    private var hiddenSelectedLoaderVersionCount: Int {
        max(selectedLoaderVersions.count - visibleSelectedLoaderVersions.count, 0)
    }

    private var selectedLoaderVersionTitle: String {
        if let selected = selectedLoaderVersions.first(where: { $0.loaderVersion == loaderVersion }) {
            return loaderVersionTitle(selected)
        }
        if let loaderVersion {
            return loaderVersion
        }
        return selectedLoaderOption?.recommendedVersion ?? "-"
    }

    @ViewBuilder
    private var versionPicker: some View {
        if loader != nil {
            SettingsRow(
                title: localizedString(theme.language, english: "Loader Version", chinese: "加载器版本", italian: "Versione loader", french: "Version du loader", spanish: "Versión del loader"),
                systemImage: "number"
            ) {
                MinecraftInstallVersionMenu(
                    title: selectedLoaderVersionTitle,
                    isEmpty: selectedLoaderVersions.isEmpty,
                    emptyTitle: versionOptionsStatus.isEmpty ? localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando") : versionOptionsStatus
                ) {
                    ForEach(visibleSelectedLoaderVersions) { metadata in
                        Button(loaderVersionTitle(metadata)) {
                            loaderVersion = metadata.loaderVersion
                        }
                    }
                    if hiddenSelectedLoaderVersionCount > 0 {
                        Divider()
                        Text(localizedString(theme.language, english: "Showing first \(versionMenuLimit) versions", chinese: "已显示前 \(versionMenuLimit) 个版本", italian: "Mostrate prime \(versionMenuLimit) versioni", french: "Affiche les \(versionMenuLimit) premieres versions", spanish: "Mostrando primeras \(versionMenuLimit) versiones"))
                    }
                }
                .disabled(selectedLoaderVersions.isEmpty)
            }
        }
    }

    private func loaderVersionTitle(_ metadata: LoaderMetadata) -> String {
        metadata.stable ? metadata.loaderVersion : "\(metadata.loaderVersion) · Beta"
    }
}

struct MinecraftInstallShaderPanel: View {
    @Binding var shaderLoader: ShaderLoaderChoice
    @Binding var shaderLoaderVersion: String?

    let shaderReleases: [OnlineRelease]
    let versionOptionsStatus: String
    let versionMenuLimit: Int
    let choiceState: (ShaderLoaderChoice) -> InstallChoicePreflightState
    let isChoiceDisabled: (ShaderLoaderChoice) -> Bool
    let helpText: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .panel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Shader Loader", chinese: "光影加载器", italian: "Shader loader", french: "Loader de shaders", spanish: "Loader de shaders"),
                    systemImage: "sparkles.rectangle.stack"
                )
                HStack(spacing: 8) {
                    ForEach(ShaderLoaderChoice.allCases) { choice in
                        MinecraftInstallChoiceButton(
                            title: choice.title,
                            isSelected: shaderLoader == choice,
                            disabled: isChoiceDisabled(choice),
                            state: choiceState(choice)
                        ) {
                            shaderLoaderVersion = nil
                            shaderLoader = choice
                        }
                    }
                }
                versionPicker
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var visibleShaderReleases: [OnlineRelease] {
        Array(shaderReleases.prefix(versionMenuLimit))
    }

    private var hiddenShaderReleaseCount: Int {
        max(shaderReleases.count - visibleShaderReleases.count, 0)
    }

    private var selectedShaderReleaseTitle: String {
        if let selected = shaderReleases.first(where: { $0.id == shaderLoaderVersion }) {
            return shaderReleaseTitle(selected)
        }
        return shaderReleases.first.map(shaderReleaseTitle) ?? "-"
    }

    @ViewBuilder
    private var versionPicker: some View {
        if shaderLoader == .iris || shaderLoader == .oculus {
            SettingsRow(
                title: localizedString(theme.language, english: "Shader Loader Version", chinese: "光影加载器版本", italian: "Versione shader loader", french: "Version du loader shader", spanish: "Versión del loader de shaders"),
                systemImage: "sparkles"
            ) {
                MinecraftInstallVersionMenu(
                    title: selectedShaderReleaseTitle,
                    isEmpty: shaderReleases.isEmpty,
                    emptyTitle: versionOptionsStatus.isEmpty ? localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando") : versionOptionsStatus
                ) {
                    ForEach(visibleShaderReleases) { release in
                        Button(shaderReleaseTitle(release)) {
                            shaderLoaderVersion = release.id
                        }
                    }
                    if hiddenShaderReleaseCount > 0 {
                        Divider()
                        Text(localizedString(theme.language, english: "Showing first \(versionMenuLimit) releases", chinese: "已显示前 \(versionMenuLimit) 个 release", italian: "Mostrate prime \(versionMenuLimit) release", french: "Affiche les \(versionMenuLimit) premieres releases", spanish: "Mostrando primeras \(versionMenuLimit) releases"))
                    }
                }
                .disabled(shaderReleases.isEmpty)
            }
        }
    }

    private func shaderReleaseTitle(_ release: OnlineRelease) -> String {
        let versionText = release.versionNumber.isEmpty ? release.versionName : release.versionNumber
        return release.releaseType == .release ? versionText : "\(versionText) · \(release.releaseType.rawValue.capitalized)"
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
