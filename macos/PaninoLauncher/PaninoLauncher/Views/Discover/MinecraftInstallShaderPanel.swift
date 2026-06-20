import SwiftUI

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
