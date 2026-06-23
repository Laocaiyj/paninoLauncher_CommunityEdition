import SwiftUI

extension OnlineContentDiscoveryPage {
    var targetContextBar: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedString(theme.language, english: "Minecraft version filter", chinese: "Minecraft 版本过滤", italian: "Filtro versione Minecraft", french: "Filtre de version Minecraft", spanish: "Filtro de versión de Minecraft"))
                        .font(.caption.weight(.semibold))
                    Text(targetContextSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                    refreshOnlineContent()
                }
                .disabled(!canSearchSelectedSource || onlineContentStore.isLoading)
                Menu {
                    Button(localizedString(theme.language, english: "All Minecraft versions", chinese: "全部 Minecraft 版本", italian: "Tutte le versioni Minecraft", french: "Toutes les versions Minecraft", spanish: "Todas las versiones de Minecraft")) {
                        useMinecraftVersionFilter = false
                        selectedContentMinecraftVersionID = nil
                    }
                    Divider()
                    if releaseMinecraftVersions.isEmpty {
                        Button(AppText.refresh.localized(theme.language)) {
                            refreshMinecraftVersions()
                        }
                    } else {
                        ForEach(releaseMinecraftVersions) { version in
                            Button(versionMenuTitle(version)) {
                                useMinecraftVersionFilter = true
                                selectedContentMinecraftVersionID = version.id
                            }
                        }
                    }
                } label: {
                    Label(localizedString(theme.language, english: "Choose Version", chinese: "选择版本", italian: "Scegli versione", french: "Choisir la version", spanish: "Elegir versión"), systemImage: "arrow.left.arrow.right")
                }
                .menuStyle(.button)
            }
        }
    }

    var targetContextSummary: String {
        guard useMinecraftVersionFilter else {
            return localizedString(theme.language, english: "No Minecraft version filter selected. Search results are not tied to a local instance.", chinese: "未选择 Minecraft 版本过滤；搜索结果不会绑定本地实例。", italian: "Nessun filtro versione Minecraft selezionato.", french: "Aucun filtre de version Minecraft sélectionné.", spanish: "No se seleccionó filtro de versión de Minecraft.")
        }
        guard let selectedContentMinecraftVersionID else {
            return localizedString(theme.language, english: "Choose a Minecraft version to filter compatible content.", chinese: "请选择 Minecraft 版本，用于筛选兼容内容。", italian: "Scegli una versione Minecraft per filtrare i contenuti compatibili.", french: "Choisissez une version Minecraft pour filtrer le contenu compatible.", spanish: "Elige una versión de Minecraft para filtrar contenido compatible.")
        }
        return localizedString(theme.language, english: "Browsing content compatible with Minecraft \(selectedContentMinecraftVersionID). Install targets are chosen later.", chinese: "正在浏览兼容 Minecraft \(selectedContentMinecraftVersionID) 的内容；安装目标稍后再选。", italian: "Contenuti compatibili con Minecraft \(selectedContentMinecraftVersionID).", french: "Contenu compatible avec Minecraft \(selectedContentMinecraftVersionID).", spanish: "Contenido compatible con Minecraft \(selectedContentMinecraftVersionID).")
    }

    func versionMenuTitle(_ version: MinecraftVersionInfo) -> String {
        let kind = version.kind.title(language: theme.language)
        if version.id == versionStore.latestReleaseID {
            return localizedString(theme.language, english: "\(version.id) · Latest release", chinese: "\(version.id) · 最新正式版", italian: "\(version.id) · Ultima release", french: "\(version.id) · Dernière release", spanish: "\(version.id) · Última release")
        }
        return "\(version.id) · \(kind)"
    }
}
