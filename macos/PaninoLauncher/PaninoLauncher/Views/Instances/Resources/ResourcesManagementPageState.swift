import Foundation

struct PendingContentUpdateReview: Identifiable {
    let id = UUID()
    let response: CoreContentUpdatePlanResponse
}

extension ResourcesManagementPage {
    var filteredManagedAssets: [ManagedAsset] {
        let query = assetSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return versionStore.managedAssets }
        return versionStore.managedAssets.filter { asset in
            [
                asset.name,
                asset.metadata.displayName,
                asset.metadata.version,
                asset.metadata.summary,
                asset.source,
                asset.projectURL?.absoluteString
            ]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var groupedAssets: [(title: String, assets: [ManagedAsset])] {
        [
            (
                localizedString(theme.language, english: "Needs Attention", chinese: "需要处理", italian: "Richiede attenzione", french: "À vérifier", spanish: "Requiere atención"),
                filteredManagedAssets.filter { $0.conflictMessage != nil }
            ),
            (
                localizedString(theme.language, english: "Enabled", chinese: "已启用", italian: "Abilitati", french: "Activés", spanish: "Activados"),
                filteredManagedAssets.filter { $0.conflictMessage == nil && $0.isEnabled }
            ),
            (
                localizedString(theme.language, english: "Disabled", chinese: "已禁用", italian: "Disabilitati", french: "Désactivés", spanish: "Desactivados"),
                filteredManagedAssets.filter { $0.conflictMessage == nil && !$0.isEnabled }
            )
        ]
        .filter { !$0.assets.isEmpty }
    }

    var selectedAssets: [ManagedAsset] {
        versionStore.managedAssets.filter { selectedAssetIDs.contains($0.id) }
    }

    var installActionTitle: String {
        switch versionStore.selectedAssetKind {
        case .mods:
            return localizedString(theme.language, english: "Install Mods", chinese: "安装 Mod", italian: "Installa Mod", french: "Installer Mods", spanish: "Instalar Mods")
        case .resourcePacks:
            return localizedString(theme.language, english: "Install Resources", chinese: "安装资源包", italian: "Installa risorse", french: "Installer ressources", spanish: "Instalar recursos")
        case .shaderPacks:
            return localizedString(theme.language, english: "Install Shaders", chinese: "安装光影包", italian: "Installa shader", french: "Installer shaders", spanish: "Instalar shaders")
        }
    }

    var unavailableTitle: String {
        switch versionStore.selectedAssetKind {
        case .mods:
            return localizedString(theme.language, english: "Mods Need a Loader", chinese: "Mod 需要加载器", italian: "Le mod richiedono un loader", french: "Les mods nécessitent un loader", spanish: "Los mods necesitan un loader")
        case .shaderPacks:
            return localizedString(theme.language, english: "Shaders Need Shader Support", chinese: "光影需要兼容组件", italian: "Gli shader richiedono supporto", french: "Les shaders nécessitent un support", spanish: "Los shaders necesitan soporte")
        case .resourcePacks:
            return localizedString(theme.language, english: "Resource Packs Unavailable", chinese: "资源包不可用", italian: "Pacchetti risorse non disponibili", french: "Packs indisponibles", spanish: "Recursos no disponibles")
        }
    }

    var unavailableDescription: String {
        switch versionStore.selectedAssetKind {
        case .mods:
            return localizedString(theme.language, english: "This Vanilla configuration has no Fabric, Forge, Quilt, or NeoForge loader. Install a Loader through the configuration install flow before managing Mods.", chinese: "这个原版配置没有 Fabric、Forge、Quilt 或 NeoForge。请先通过配置安装流程安装 Loader，再管理 Mod。", italian: "Questa configurazione Vanilla non ha loader.", french: "Cette configuration Vanilla n'a pas de loader.", spanish: "Esta configuración Vanilla no tiene loader.")
        case .shaderPacks:
            return localizedString(theme.language, english: "Install Iris, Oculus, or OptiFine through the Loader-aware flow before managing shader packs.", chinese: "请先通过带 Loader 预检的流程安装 Iris、Oculus 或 OptiFine，再管理光影包。", italian: "Installa Iris, Oculus o OptiFine prima.", french: "Installez Iris, Oculus ou OptiFine d'abord.", spanish: "Instala Iris, Oculus u OptiFine primero.")
        case .resourcePacks:
            return localizedString(theme.language, english: "Resource packs are normally available for every configuration.", chinese: "资源包通常可用于所有游戏配置。", italian: "I pacchetti risorse sono normalmente disponibili.", french: "Les packs sont normalement disponibles.", spanish: "Los recursos suelen estar disponibles.")
        }
    }

    func isCurrentAssetKindAvailable(capabilities: GameConfigurationCapabilities?) -> Bool {
        guard let capabilities else { return false }
        switch versionStore.selectedAssetKind {
        case .mods:
            return capabilities.canManageMods
        case .resourcePacks:
            return capabilities.canManageResourcePacks
        case .shaderPacks:
            return capabilities.canManageShaderPacks
        }
    }
}
