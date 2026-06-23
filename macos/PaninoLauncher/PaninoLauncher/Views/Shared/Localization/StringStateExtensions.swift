import Foundation

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
