import SwiftUI

extension VersionUsageFilter {
    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return localizedString(language, english: "All")
        case .installed:
            return localizedString(language, english: "Installed")
        case .usedByInstance:
            return localizedString(language, english: "Used by Config")
        }
    }
}

extension ManagedAssetSort {
    func title(language: AppLanguage) -> String {
        switch self {
        case .name:
            return localizedString(language, english: "Name", chinese: "名称", italian: "Nome", french: "Nom", spanish: "Nombre")
        case .status:
            return localizedString(language, english: "Status")
        case .source:
            return localizedString(language, english: "Source", chinese: "来源", italian: "Fonte", french: "Source", spanish: "Fuente")
        case .updated:
            return localizedString(language, english: "Updated", chinese: "更新", italian: "Aggiornato", french: "Mis à jour", spanish: "Actualizado")
        case .size:
            return localizedString(language, english: "Size", chinese: "大小", italian: "Dimensione", french: "Taille", spanish: "Tamaño")
        }
    }
}

extension MinecraftVersionKind {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .release: return "正式版"
            case .snapshot: return "快照版"
            case .oldBeta: return "旧 Beta"
            case .oldAlpha: return "旧 Alpha"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .release: return "Stabile"
            case .snapshot: return "Snapshot"
            case .oldBeta: return "Vecchia Beta"
            case .oldAlpha: return "Vecchia Alpha"
            }
        case .french:
            switch self {
            case .release: return "Stable"
            case .snapshot: return "Snapshot"
            case .oldBeta: return "Ancienne bêta"
            case .oldAlpha: return "Ancienne alpha"
            }
        case .spanish:
            switch self {
            case .release: return "Estable"
            case .snapshot: return "Snapshot"
            case .oldBeta: return "Beta antigua"
            case .oldAlpha: return "Alpha antigua"
            }
        }
    }
}

extension ManagedAssetKind {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .mods: return "Mod"
            case .resourcePacks: return "资源包"
            case .shaderPacks: return "光影包"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .mods: return "Mod"
            case .resourcePacks: return "Resource pack"
            case .shaderPacks: return "Shader pack"
            }
        case .french:
            switch self {
            case .mods: return "Mods"
            case .resourcePacks: return "Packs de ressources"
            case .shaderPacks: return "Packs de shaders"
            }
        case .spanish:
            switch self {
            case .mods: return "Mods"
            case .resourcePacks: return "Paquetes de recursos"
            case .shaderPacks: return "Paquetes de shaders"
            }
        }
    }
}
