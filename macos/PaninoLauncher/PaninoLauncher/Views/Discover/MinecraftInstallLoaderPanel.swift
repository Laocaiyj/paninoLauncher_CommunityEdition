import SwiftUI

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
