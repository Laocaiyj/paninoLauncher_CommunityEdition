import Foundation

func recoveryCauses(errorCode: String?, language: AppLanguage) -> [String] {
    let lowercased = errorCode?.lowercased() ?? ""
    if lowercased.contains("shader_release_not_found") {
        return [
            localizedString(language, english: "The selected shader loader has no public compatible release for this Minecraft version and loader.", chinese: "所选光影加载器暂无适配当前 Minecraft 版本和 Loader 的公开下载版本。", italian: "The selected shader loader has no public compatible release for this Minecraft version and loader.", french: "The selected shader loader has no public compatible release for this Minecraft version and loader.", spanish: "The selected shader loader has no public compatible release for this Minecraft version and loader."),
            localizedString(language, english: "The upstream project may not support this combination yet.", chinese: "上游项目可能还没有支持这个组合。", italian: "The upstream project may not support this combination yet.", french: "The upstream project may not support this combination yet.", spanish: "The upstream project may not support this combination yet.")
        ]
    }
    if lowercased.contains("shader_loader_incompatible") {
        return [
            localizedString(language, english: "The selected shader loader belongs to a different loader ecosystem.", chinese: "所选光影加载器属于另一个 Loader 生态。", italian: "The selected shader loader belongs to a different loader ecosystem.", french: "The selected shader loader belongs to a different loader ecosystem.", spanish: "The selected shader loader belongs to a different loader ecosystem."),
            localizedString(language, english: "Iris is for Fabric/Quilt, while Oculus is for Forge/NeoForge.", chinese: "Iris 适用于 Fabric/Quilt，Oculus 适用于 Forge/NeoForge。", italian: "Iris is for Fabric/Quilt, while Oculus is for Forge/NeoForge.", french: "Iris is for Fabric/Quilt, while Oculus is for Forge/NeoForge.", spanish: "Iris is for Fabric/Quilt, while Oculus is for Forge/NeoForge.")
        ]
    }
    if lowercased.contains("loader_version_not_found") {
        return [
            localizedString(language, english: "The selected loader does not publish a compatible version for this Minecraft version.", chinese: "所选 Loader 没有发布适配该 Minecraft 版本的版本。", italian: "The selected loader does not publish a compatible version for this Minecraft version.", french: "The selected loader does not publish a compatible version for this Minecraft version.", spanish: "The selected loader does not publish a compatible version for this Minecraft version."),
            localizedString(language, english: "This is a compatibility result, not a local file problem.", chinese: "这是兼容性结论，不是本地文件问题。", italian: "This is a compatibility result, not a local file problem.", french: "This is a compatibility result, not a local file problem.", spanish: "This is a compatibility result, not a local file problem.")
        ]
    }
    if lowercased.contains("loader_metadata_source_failed") || lowercased.contains("loader_profile_fetch_failed") {
        return [
            localizedString(language, english: "Core could not read the selected loader metadata/profile source.", chinese: "Core 无法读取所选 Loader 的元数据或 profile 源。", italian: "Core could not read the selected loader metadata/profile source.", french: "Core could not read the selected loader metadata/profile source.", spanish: "Core could not read the selected loader metadata/profile source."),
            localizedString(language, english: "Network, proxy, or upstream service state may be blocking the request.", chinese: "网络、代理或上游服务状态可能阻止了请求。", italian: "Network, proxy, or upstream service state may be blocking the request.", french: "Network, proxy, or upstream service state may be blocking the request.", spanish: "Network, proxy, or upstream service state may be blocking the request.")
        ]
    }
    if lowercased.contains("manual_install_required") {
        return [
            localizedString(language, english: "This component is not safe to install automatically yet.", chinese: "该组件暂不适合自动安装。", italian: "This component is not safe to install automatically yet.", french: "This component is not safe to install automatically yet.", spanish: "This component is not safe to install automatically yet."),
            localizedString(language, english: "Core blocked the operation before writing a partial instance.", chinese: "Core 已在写入半成品实例前拦截。", italian: "Core blocked the operation before writing a partial instance.", french: "Core blocked the operation before writing a partial instance.", spanish: "Core blocked the operation before writing a partial instance.")
        ]
    }
    if lowercased.contains("dependency") {
        return [
            localizedString(language, english: "A required dependency could not be resolved or did not provide a compatible download."),
            localizedString(language, english: "The selected game version, loader, or content source may not match the dependency requirements.")
        ]
    }
    if lowercased.contains("api_key") {
        return [
            localizedString(language, english: "The selected content source requires a valid API key."),
            localizedString(language, english: "The key may be missing, expired, or rejected by the upstream service.")
        ]
    }
    if lowercased.contains("loader_installer") {
        return [
            localizedString(language, english: "The loader installer failed before the instance was ready."),
            localizedString(language, english: "The loader version may be incompatible with this Minecraft version or source response.")
        ]
    }
    if lowercased.contains("proxy") || lowercased.contains("source_host") {
        return [
            localizedString(language, english: "The configured proxy or selected source host rejected the request."),
            localizedString(language, english: "A mirror/source outage or proxy rule may be blocking the download.")
        ]
    }
    if lowercased.contains("target_directory") {
        return [
            localizedString(language, english: "The target game directory is missing or not writable."),
            localizedString(language, english: "Folder permissions, sandbox prompts, or a moved instance path may block writes.")
        ]
    }
    if lowercased.contains("network") || lowercased.contains("timeout") {
        return [
            localizedString(language, english: "The network request timed out or was blocked.", chinese: "网络请求超时或被阻止。", italian: "La richiesta di rete è scaduta o bloccata.", french: "La requête réseau a expiré ou a été bloquée.", spanish: "La solicitud de red agotó el tiempo o fue bloqueada."),
            localizedString(language, english: "Proxy settings or mirror source may be unavailable.", chinese: "代理设置或镜像源可能不可用。", italian: "Proxy o mirror potrebbero non essere disponibili.", french: "Le proxy ou le miroir peuvent être indisponibles.", spanish: "El proxy o espejo puede no estar disponible.")
        ]
    }
    if lowercased.contains("hash") || lowercased.contains("mismatch") {
        return [
            localizedString(language, english: "A cached artifact does not match the expected checksum.", chinese: "缓存文件与预期校验和不一致。", italian: "Un file in cache non corrisponde al checksum atteso.", french: "Un fichier en cache ne correspond pas à la somme attendue.", spanish: "Un archivo en caché no coincide con la suma esperada."),
            localizedString(language, english: "The download may have been interrupted or corrupted.", chinese: "下载可能被中断或已损坏。", italian: "Il download potrebbe essere stato interrotto o corrotto.", french: "Le téléchargement peut avoir été interrompu ou corrompu.", spanish: "La descarga pudo interrumpirse o dañarse.")
        ]
    }
    if lowercased.contains("permission") || lowercased.contains("denied") {
        return [
            localizedString(language, english: "The launcher cannot write to the selected folder.", chinese: "启动器无法写入所选文件夹。", italian: "Il launcher non può scrivere nella cartella scelta.", french: "Le lanceur ne peut pas écrire dans le dossier choisi.", spanish: "El launcher no puede escribir en la carpeta elegida."),
            localizedString(language, english: "macOS privacy permissions or file ownership may block access.", chinese: "macOS 隐私权限或文件所有权可能阻止访问。", italian: "Privacy macOS o proprietà file possono bloccare l'accesso.", french: "La confidentialité macOS ou les droits du fichier peuvent bloquer l'accès.", spanish: "La privacidad de macOS o permisos de archivo pueden bloquear el acceso.")
        ]
    }
    if lowercased.contains("disk") || lowercased.contains("space") {
        return [
            localizedString(language, english: "The disk may not have enough free space.", chinese: "磁盘空间可能不足。", italian: "Il disco potrebbe non avere spazio sufficiente.", french: "Le disque peut manquer d'espace libre.", spanish: "El disco puede no tener espacio suficiente."),
            localizedString(language, english: "The target volume may be read-only or temporarily unavailable.", chinese: "目标卷可能只读或暂时不可用。", italian: "Il volume di destinazione potrebbe essere solo lettura o non disponibile.", french: "Le volume cible peut être en lecture seule ou indisponible.", spanish: "El volumen destino puede ser de solo lectura o no estar disponible.")
        ]
    }
    if lowercased.contains("install_failed") || lowercased.contains("content_install_failed") {
        return [
            localizedString(language, english: "Core failed while preparing or writing install files.", chinese: "Core 在准备或写入安装文件时失败。", italian: "Core non è riuscito a preparare o scrivere i file.", french: "Core a échoué pendant la préparation ou l'écriture.", spanish: "Core falló al preparar o escribir archivos."),
            localizedString(language, english: "The selected version metadata, target directory, or dependency plan may be invalid.", chinese: "所选版本元数据、目标目录或依赖计划可能无效。", italian: "Metadati versione, cartella o piano dipendenze potrebbero non essere validi.", french: "Les métadonnées, le dossier cible ou le plan de dépendances peuvent être invalides.", spanish: "Los metadatos, carpeta o plan de dependencias pueden no ser válidos.")
        ]
    }
    return [
        localizedString(language, english: "Core reported a task error.", chinese: "Core 报告了任务错误。", italian: "Core ha segnalato un errore dell'attività.", french: "Core a signalé une erreur de tâche.", spanish: "Core informó un error de tarea."),
        localizedString(language, english: "The task may be retriable after Core, Java, network, or file state changes.", chinese: "Core、Java、网络或文件状态变化后，该任务可能可以重试。", italian: "L'attività può essere ritentata dopo modifiche a Core, Java, rete o file.", french: "La tâche peut être réessayée après changement de Core, Java, réseau ou fichiers.", spanish: "La tarea puede reintentarse tras cambios en Core, Java, red o archivos.")
    ]
}

func recoveryActions(errorCode: String?, language: AppLanguage) -> [String] {
    let lowercased = errorCode?.lowercased() ?? ""
    if lowercased.contains("shader_release_not_found") || lowercased.contains("shader_loader_incompatible") {
        return [
            localizedString(language, english: "Switch Iris to Fabric/Quilt, or switch Oculus to Forge/NeoForge.", chinese: "Iris 请搭配 Fabric/Quilt；Oculus 请搭配 Forge/NeoForge。", italian: "Switch Iris to Fabric/Quilt, or switch Oculus to Forge/NeoForge.", french: "Switch Iris to Fabric/Quilt, or switch Oculus to Forge/NeoForge.", spanish: "Switch Iris to Fabric/Quilt, or switch Oculus to Forge/NeoForge."),
            localizedString(language, english: "Choose None if you want to install shader support manually later.", chinese: "如果要稍后手动安装光影支持，请选择 None。", italian: "Choose None if you want to install shader support manually later.", french: "Choose None if you want to install shader support manually later.", spanish: "Choose None if you want to install shader support manually later.")
        ]
    }
    if lowercased.contains("loader_version_not_found") {
        return [
            localizedString(language, english: "Choose another Minecraft version or another loader.", chinese: "请选择另一个 Minecraft 版本或换用其他 Loader。", italian: "Choose another Minecraft version or another loader.", french: "Choose another Minecraft version or another loader.", spanish: "Choose another Minecraft version or another loader."),
            localizedString(language, english: "Retry after refreshing loader metadata.", chinese: "刷新 Loader 元数据后再重试。", italian: "Retry after refreshing loader metadata.", french: "Retry after refreshing loader metadata.", spanish: "Retry after refreshing loader metadata.")
        ]
    }
    if lowercased.contains("loader_metadata_source_failed") || lowercased.contains("loader_profile_fetch_failed") {
        return [
            localizedString(language, english: "Check proxy/source settings, then run the install preflight again.", chinese: "检查代理/下载源设置后重新运行安装预检。", italian: "Check proxy/source settings, then run the install preflight again.", french: "Check proxy/source settings, then run the install preflight again.", spanish: "Check proxy/source settings, then run the install preflight again."),
            localizedString(language, english: "Export diagnostics if the same source keeps failing.", chinese: "如果同一来源持续失败，请导出诊断包。", italian: "Export diagnostics if the same source keeps failing.", french: "Export diagnostics if the same source keeps failing.", spanish: "Export diagnostics if the same source keeps failing.")
        ]
    }
    if lowercased.contains("manual_install_required") {
        return [
            localizedString(language, english: "Switch to None and install this component manually after the instance is created.", chinese: "切换为 None，创建实例后再手动安装该组件。", italian: "Switch to None and install this component manually after the instance is created.", french: "Switch to None and install this component manually after the instance is created.", spanish: "Switch to None and install this component manually after the instance is created."),
            localizedString(language, english: "Use Iris or Oculus when a fully automatic shader-loader install is needed.", chinese: "需要全自动安装时，请选择 Iris 或 Oculus。", italian: "Use Iris or Oculus when a fully automatic shader-loader install is needed.", french: "Use Iris or Oculus when a fully automatic shader-loader install is needed.", spanish: "Use Iris or Oculus when a fully automatic shader-loader install is needed.")
        ]
    }
    if lowercased.contains("dependency") {
        return [
            localizedString(language, english: "Open the install plan and choose a compatible version/loader."),
            localizedString(language, english: "Retry with Modrinth or add the required dependency manually if the source cannot resolve it.")
        ]
    }
    if lowercased.contains("api_key") {
        return [
            localizedString(language, english: "Add or update the API key in Settings."),
            localizedString(language, english: "Switch to Modrinth if you do not need the API-key source.")
        ]
    }
    if lowercased.contains("loader_installer") {
        return [
            localizedString(language, english: "Retry with a supported loader/version combination."),
            localizedString(language, english: "Switch download source if loader metadata cannot be fetched.")
        ]
    }
    if lowercased.contains("proxy") || lowercased.contains("source_host") {
        return [
            localizedString(language, english: "Run Check Connection in Settings."),
            localizedString(language, english: "Change proxy/source settings, then retry the task.")
        ]
    }
    if lowercased.contains("target_directory") {
        return [
            localizedString(language, english: "Choose a writable game directory."),
            localizedString(language, english: "Open the instance folder and confirm it still exists.")
        ]
    }
    if lowercased.contains("network") || lowercased.contains("timeout") {
        return [
            localizedString(language, english: "Check network connectivity and proxy settings.", chinese: "检查网络连接和代理设置。", italian: "Controlla rete e proxy.", french: "Vérifiez la connexion réseau et le proxy.", spanish: "Comprueba red y proxy."),
            localizedString(language, english: "Retry with the official or mirror download source.", chinese: "使用官方或镜像下载源重试。", italian: "Riprova con sorgente ufficiale o mirror.", french: "Réessayez avec la source officielle ou miroir.", spanish: "Reintenta con fuente oficial o espejo.")
        ]
    }
    if lowercased.contains("hash") || lowercased.contains("mismatch") {
        return [
            localizedString(language, english: "Clear corrupted cache from Tasks.", chinese: "在任务页清理损坏缓存。", italian: "Pulisci la cache corrotta da Attività.", french: "Videz le cache corrompu depuis Tâches.", spanish: "Limpia la caché dañada desde Tareas."),
            localizedString(language, english: "Retry the failed install or download task.", chinese: "重试失败的安装或下载任务。", italian: "Riprova installazione o download fallito.", french: "Réessayez l'installation ou le téléchargement échoué.", spanish: "Reintenta instalación o descarga fallida.")
        ]
    }
    if lowercased.contains("permission") || lowercased.contains("denied") {
        return [
            localizedString(language, english: "Choose a writable game directory.", chinese: "选择可写的游戏目录。", italian: "Scegli una cartella di gioco scrivibile.", french: "Choisissez un dossier de jeu inscriptible.", spanish: "Elige una carpeta de juego escribible."),
            localizedString(language, english: "Grant file access permissions if macOS prompts again.", chinese: "如果 macOS 再次提示，请授予文件访问权限。", italian: "Concedi accesso ai file se macOS lo richiede.", french: "Accordez l'accès aux fichiers si macOS le redemande.", spanish: "Concede acceso a archivos si macOS lo solicita.")
        ]
    }
    if lowercased.contains("disk") || lowercased.contains("space") {
        return [
            localizedString(language, english: "Free disk space on the target volume.", chinese: "释放目标磁盘空间。", italian: "Libera spazio sul volume di destinazione.", french: "Libérez de l'espace sur le volume cible.", spanish: "Libera espacio en el volumen destino."),
            localizedString(language, english: "Retry after clearing incomplete downloads.", chinese: "清理未完成下载后重试。", italian: "Riprova dopo aver pulito download incompleti.", french: "Réessayez après avoir supprimé les téléchargements incomplets.", spanish: "Reintenta tras limpiar descargas incompletas.")
        ]
    }
    if lowercased.contains("install_failed") || lowercased.contains("content_install_failed") {
        return [
            localizedString(language, english: "Open logs and inspect the Core error detail.", chinese: "打开日志并查看 Core 错误详情。", italian: "Apri i log e controlla il dettaglio Core.", french: "Ouvrez les journaux et inspectez le détail Core.", spanish: "Abre registros y revisa el detalle de Core."),
            localizedString(language, english: "Retry after changing version, dependency, network, or target folder state.", chinese: "调整版本、依赖、网络或目标目录状态后重试。", italian: "Riprova dopo aver corretto versione, dipendenze, rete o cartella.", french: "Réessayez après correction de version, dépendances, réseau ou dossier.", spanish: "Reintenta tras corregir versión, dependencias, red o carpeta.")
        ]
    }
    return [
        localizedString(language, english: "Retry the task once.", chinese: "先重试一次任务。", italian: "Riprova una volta l'attività.", french: "Réessayez la tâche une fois.", spanish: "Reintenta la tarea una vez."),
        localizedString(language, english: "Export diagnostics if the failure repeats.", chinese: "如果问题重复，导出诊断包。", italian: "Esporta la diagnostica se l'errore si ripete.", french: "Exportez le diagnostic si l'échec se répète.", spanish: "Exporta diagnóstico si se repite.")
    ]
}
