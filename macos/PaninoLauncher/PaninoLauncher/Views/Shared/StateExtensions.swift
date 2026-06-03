import SwiftUI

extension CoreConnectionState {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .stopped:
            return localized(language, english: "Core stopped", chinese: "Core 已停止", italian: "Core fermo", french: "Core arrêté", spanish: "Core detenido")
        case .starting:
            return localized(language, english: "Starting Core", chinese: "正在启动 Core", italian: "Avvio Core", french: "Démarrage Core", spanish: "Iniciando Core")
        case .running:
            return localized(language, english: "Core connected", chinese: "Core 已连接", italian: "Core connesso", french: "Core connecté", spanish: "Core conectado")
        case .stopping:
            return localized(language, english: "Stopping Core", chinese: "正在停止 Core", italian: "Arresto Core", french: "Arrêt Core", spanish: "Deteniendo Core")
        case .failed:
            return localized(language, english: "Core failed", chinese: "Core 失败", italian: "Errore Core", french: "Échec Core", spanish: "Error de Core")
        }
    }

    private func localized(
        _ language: AppLanguage,
        english: String,
        chinese: String,
        italian: String,
        french: String,
        spanish: String
    ) -> String {
        switch language {
        case .chineseSimplified: return chinese
        case .english: return english
        case .italian: return italian
        case .french: return french
        case .spanish: return spanish
        }
    }
}

extension AccountConnectionState {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .signedOut:
            return AppText.signedOut.localized(language)
        case .restoring:
            return AppText.restoring.localized(language)
        case .waitingForDeviceCode:
            return AppText.waiting.localized(language)
        case .signedIn(let account):
            switch language {
            case .chineseSimplified:
                return "已登录为 \(account.name)"
            case .english:
                return "Signed in as \(account.name)"
            case .italian:
                return "Connesso come \(account.name)"
            case .french:
                return "Connecté en tant que \(account.name)"
            case .spanish:
                return "Conectado como \(account.name)"
            }
        case .failed:
            return AppText.error.localized(language)
        }
    }
}

extension AccountLoginStatus {
    var badgeStyle: StatusBadge.Style {
        switch self {
        case .signedIn:
            return .success
        case .signedOut:
            return .neutral
        case .expired:
            return .warning
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .signedIn:
            return AppText.signedIn.localized(language)
        case .signedOut:
            return AppText.signedOut.localized(language)
        case .expired:
            return localizedString(language, english: "Expired", chinese: "已过期", italian: "Scaduto", french: "Expiré", spanish: "Expirada")
        }
    }
}

extension TaskState {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .queued:
            switch language {
            case .chineseSimplified: return "排队中"
            case .english: return "Queued"
            case .italian: return "In coda"
            case .french: return "En file"
            case .spanish: return "En cola"
            }
        case .running:
            return AppText.running.localized(language)
        case .succeeded:
            return AppText.ready.localized(language)
        case .failed:
            return AppText.failed.localized(language)
        case .cancelled:
            return AppText.cancel.localized(language)
        }
    }
}

extension InstanceStatus {
    func title(language: AppLanguage) -> String {
        switch self {
        case .notInstalled:
            return localizedString(language, english: "Needs Install")
        case .ready:
            return localizedString(language, english: "Ready")
        case .installing:
            return AppText.downloading.localized(language)
        case .running:
            return AppText.running.localized(language)
        case .failed:
            return AppText.failed.localized(language)
        }
    }
}

extension GameInstance {
    func loaderTitle(language: AppLanguage, includesVersion: Bool = false) -> String {
        guard let loader else {
            return localizedString(language, english: "Vanilla")
        }
        let title = loader.title
        guard includesVersion, let loaderVersion, !loaderVersion.isEmpty else {
            return title
        }
        return "\(title) \(loaderVersion)"
    }

    func metadataLine(language: AppLanguage, includesLoaderVersion: Bool = false) -> [String] {
        [
            localizedString(language, english: group),
            "Minecraft \(minecraftVersion)",
            loaderTitle(language: language, includesVersion: includesLoaderVersion)
        ]
    }
}

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

extension TaskRecordState {
    var badgeStyle: StatusBadge.Style {
        switch self {
        case .queued, .running:
            return .running
        case .succeeded:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        case .interrupted:
            return .warning
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .queued:
            return localizedString(language, english: "Queued", chinese: "排队中", italian: "In coda", french: "En file", spanish: "En cola")
        case .running:
            return AppText.running.localized(language)
        case .succeeded:
            return localizedString(language, english: "Succeeded", chinese: "已完成", italian: "Completata", french: "Réussie", spanish: "Completada")
        case .failed:
            return AppText.failed.localized(language)
        case .cancelled:
            return AppText.cancel.localized(language)
        case .interrupted:
            return localizedString(language, english: "Interrupted", chinese: "已中断", italian: "Interrotta", french: "Interrompue", spanish: "Interrumpida")
        }
    }
}

extension TaskRecord {
    var iconName: String {
        let lowercased = kind.lowercased()
        if lowercased.contains("install") {
            return "square.and.arrow.down"
        }
        if lowercased.contains("download") {
            return "arrow.down.circle"
        }
        if lowercased.contains("check") || lowercased.contains("verify") {
            return "checkmark.seal"
        }
        if lowercased.contains("launch") {
            return "play.circle"
        }
        if lowercased.contains("log") {
            return "doc.text"
        }
        return "gearshape.2"
    }
}

extension LogPanelTab {
    func title(language: AppLanguage) -> String {
        switch self {
        case .core:
            return "Core"
        case .game:
            return localizedString(language, english: "Game", chinese: "游戏", italian: "Gioco", french: "Jeu", spanish: "Juego")
        }
    }
}

extension LogFilterLevel {
    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return localizedString(language, english: "All", chinese: "全部", italian: "Tutti", french: "Tous", spanish: "Todos")
        case .info:
            return "Info"
        case .warning:
            return localizedString(language, english: "Warning", chinese: "警告", italian: "Avviso", french: "Avertissement", spanish: "Aviso")
        case .error:
            return AppText.error.localized(language)
        }
    }
}

extension String {
    func localizedRecoveryAdvice(_ language: AppLanguage) -> String {
        if contains("network") || contains("proxy") {
            return localizedString(
                language,
                english: self,
                chinese: "检查网络连接、代理设置，然后重试任务。",
                italian: "Controlla rete e proxy, poi riprova l'attività.",
                french: "Vérifiez le réseau et le proxy, puis réessayez la tâche.",
                spanish: "Comprueba red y proxy, luego reintenta la tarea."
            )
        }
        if contains("cache") || contains("hash") {
            return localizedString(
                language,
                english: self,
                chinese: "清理损坏缓存，然后重试下载。",
                italian: "Pulisci la cache corrotta, poi riprova il download.",
                french: "Videz le cache corrompu, puis réessayez le téléchargement.",
                spanish: "Limpia la caché dañada y reintenta la descarga."
            )
        }
        if contains("permission") || contains("writable") {
            return localizedString(
                language,
                english: self,
                chinese: "检查文件夹权限，并选择可写的游戏目录。",
                italian: "Controlla i permessi e scegli una cartella scrivibile.",
                french: "Vérifiez les permissions et choisissez un dossier inscriptible.",
                spanish: "Comprueba permisos y elige una carpeta escribible."
            )
        }
        if contains("disk") || contains("space") {
            return localizedString(
                language,
                english: self,
                chinese: "释放磁盘空间，然后重试任务。",
                italian: "Libera spazio su disco, poi riprova.",
                french: "Libérez de l'espace disque, puis réessayez.",
                spanish: "Libera espacio en disco y reintenta."
            )
        }
        return localizedString(
            language,
            english: self,
            chinese: "查看技术详情；如果问题是临时性的，可以重试。",
            italian: "Controlla i dettagli tecnici; riprova se il problema è temporaneo.",
            french: "Consultez les détails techniques ; réessayez si le problème est temporaire.",
            spanish: "Revisa los detalles técnicos; reintenta si es temporal."
        )
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

extension String {
    func localizedVersionState(_ language: AppLanguage) -> String {
        switch self {
        case "Available":
            switch language {
            case .chineseSimplified: return "可用"
            case .english: return self
            case .italian: return "Disponibile"
            case .french: return "Disponible"
            case .spanish: return "Disponible"
            }
        case "Installed":
            switch language {
            case .chineseSimplified: return "已安装"
            case .english: return self
            case .italian: return "Installato"
            case .french: return "Installé"
            case .spanish: return "Instalado"
            }
        case "Not installed":
            switch language {
            case .chineseSimplified: return "未安装"
            case .english: return self
            case .italian: return "Non installato"
            case .french: return "Non installé"
            case .spanish: return "No instalado"
            }
        case "Legacy":
            switch language {
            case .chineseSimplified: return "旧版"
            case .english: return self
            case .italian: return "Legacy"
            case .french: return "Ancien"
            case .spanish: return "Legacy"
            }
        default:
            return self
        }
    }
}
