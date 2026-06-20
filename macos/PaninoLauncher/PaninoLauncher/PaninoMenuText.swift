enum PaninoMenuText {
    case about
    case settings
    case checkForUpdates
    case quit
    case launchMenu
    case instancesMenu
    case getMenu
    case tasksMenu
    case toolsMenu
    case launchSelected
    case openLaunchDashboard
    case openRecentInstance
    case checkJavaRuntime
    case manageLocalInstances
    case openInstanceFolder
    case manageResources
    case browseVersionsLoaders
    case duplicateInstance
    case deleteInstance
    case openGetPage
    case openTaskCenter
    case retryAttentionTask
    case openLogs
    case exportDiagnostics
    case copyDiagnosticSummary
    case scanJavaRuntimes
    case openDownloadCache
    case clearDownloadCache
    case openLogsFolder
    case accountSettings
    case runtimeSettings
    case downloadSettings
    case appearanceSettings
    case advancedSettings
    case openMinecraftWiki

    func localized(_ language: AppLanguage) -> String {
        switch self {
        case .about:
            return localizedString(language, english: "About Panino Launcher", chinese: "关于 Panino Launcher", italian: "Informazioni su Panino Launcher", french: "À propos de Panino Launcher", spanish: "Acerca de Panino Launcher")
        case .settings:
            return localizedString(language, english: "Settings...", chinese: "设置...", italian: "Impostazioni...", french: "Réglages...", spanish: "Ajustes...")
        case .checkForUpdates:
            return localizedString(language, english: "Check for Updates", chinese: "检查更新", italian: "Cerca aggiornamenti", french: "Rechercher des mises à jour", spanish: "Buscar actualizaciones")
        case .quit:
            return localizedString(language, english: "Quit Panino Launcher", chinese: "退出 Panino Launcher", italian: "Esci da Panino Launcher", french: "Quitter Panino Launcher", spanish: "Salir de Panino Launcher")
        case .launchMenu:
            return AppText.launch.localized(language)
        case .instancesMenu:
            return AppText.instances.localized(language)
        case .getMenu:
            return localizedString(language, english: "Get", chinese: "获取", italian: "Ottieni", french: "Obtenir", spanish: "Obtener")
        case .tasksMenu:
            return AppText.tasks.localized(language)
        case .toolsMenu:
            return localizedString(language, english: "Tools", chinese: "工具", italian: "Strumenti", french: "Outils", spanish: "Herramientas")
        case .launchSelected:
            return localizedString(language, english: "Launch Selected Instance", chinese: "启动当前实例", italian: "Avvia istanza selezionata", french: "Lancer l'instance sélectionnée", spanish: "Iniciar instancia seleccionada")
        case .openLaunchDashboard:
            return localizedString(language, english: "Open Launch Dashboard", chinese: "打开启动页", italian: "Apri dashboard avvio", french: "Ouvrir le tableau de lancement", spanish: "Abrir panel de inicio")
        case .openRecentInstance:
            return localizedString(language, english: "Open Recent Instance", chinese: "打开最近实例", italian: "Apri istanza recente", french: "Ouvrir l'instance récente", spanish: "Abrir instancia reciente")
        case .checkJavaRuntime:
            return localizedString(language, english: "Check Java Runtime", chinese: "检查 Java 运行环境", italian: "Controlla runtime Java", french: "Vérifier le runtime Java", spanish: "Comprobar runtime Java")
        case .manageLocalInstances:
            return localizedString(language, english: "Manage Local Instances", chinese: "管理本地实例", italian: "Gestisci istanze locali", french: "Gérer les instances locales", spanish: "Gestionar instancias locales")
        case .openInstanceFolder:
            return localizedString(language, english: "Open Instance Folder", chinese: "打开实例文件夹", italian: "Apri cartella istanza", french: "Ouvrir le dossier de l'instance", spanish: "Abrir carpeta de instancia")
        case .manageResources:
            return localizedString(language, english: "Manage Resources", chinese: "管理资源", italian: "Gestisci risorse", french: "Gérer les ressources", spanish: "Gestionar recursos")
        case .browseVersionsLoaders:
            return localizedString(language, english: "Versions and Loaders", chinese: "版本与加载器", italian: "Versioni e loader", french: "Versions et loaders", spanish: "Versiones y loaders")
        case .duplicateInstance:
            return localizedString(language, english: "Duplicate Selected Instance", chinese: "复制当前实例", italian: "Duplica istanza selezionata", french: "Dupliquer l'instance sélectionnée", spanish: "Duplicar instancia seleccionada")
        case .deleteInstance:
            return localizedString(language, english: "Delete Selected Instance", chinese: "删除当前实例", italian: "Elimina istanza selezionata", french: "Supprimer l'instance sélectionnée", spanish: "Eliminar instancia seleccionada")
        case .openGetPage:
            return localizedString(language, english: "Open Get Page", chinese: "打开获取页", italian: "Apri pagina Ottieni", french: "Ouvrir la page Obtenir", spanish: "Abrir página Obtener")
        case .openTaskCenter:
            return localizedString(language, english: "Open Task Center", chinese: "打开任务中心", italian: "Apri centro attività", french: "Ouvrir le centre des tâches", spanish: "Abrir centro de tareas")
        case .retryAttentionTask:
            return localizedString(language, english: "Retry Attention Task", chinese: "重试待处理任务", italian: "Riprova attività da verificare", french: "Relancer la tâche à traiter", spanish: "Reintentar tarea pendiente")
        case .openLogs:
            return localizedString(language, english: "Open Logs", chinese: "打开日志", italian: "Apri log", french: "Ouvrir les journaux", spanish: "Abrir registros")
        case .exportDiagnostics:
            return localizedString(language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter le diagnostic", spanish: "Exportar diagnóstico")
        case .copyDiagnosticSummary:
            return localizedString(language, english: "Copy Diagnostic Summary", chinese: "复制诊断摘要", italian: "Copia riepilogo diagnostico", french: "Copier le résumé diagnostic", spanish: "Copiar resumen diagnóstico")
        case .scanJavaRuntimes:
            return localizedString(language, english: "Scan Java Runtimes", chinese: "扫描 Java 运行环境", italian: "Scansiona runtime Java", french: "Scanner les runtimes Java", spanish: "Escanear runtimes Java")
        case .openDownloadCache:
            return localizedString(language, english: "Open Download Cache", chinese: "打开下载缓存", italian: "Apri cache download", french: "Ouvrir le cache de téléchargement", spanish: "Abrir caché de descargas")
        case .clearDownloadCache:
            return localizedString(language, english: "Clear Download Cache", chinese: "清理下载缓存", italian: "Pulisci cache download", french: "Vider le cache de téléchargement", spanish: "Limpiar caché de descargas")
        case .openLogsFolder:
            return localizedString(language, english: "Open Logs Folder", chinese: "打开日志文件夹", italian: "Apri cartella log", french: "Ouvrir le dossier des journaux", spanish: "Abrir carpeta de registros")
        case .accountSettings:
            return localizedString(language, english: "Account Settings", chinese: "账号设置", italian: "Impostazioni account", french: "Réglages du compte", spanish: "Ajustes de cuenta")
        case .runtimeSettings:
            return localizedString(language, english: "Runtime Settings", chinese: "运行环境设置", italian: "Impostazioni runtime", french: "Réglages runtime", spanish: "Ajustes de runtime")
        case .downloadSettings:
            return localizedString(language, english: "Download Settings", chinese: "下载设置", italian: "Impostazioni download", french: "Réglages de téléchargement", spanish: "Ajustes de descarga")
        case .appearanceSettings:
            return localizedString(language, english: "Appearance Settings", chinese: "外观设置", italian: "Impostazioni aspetto", french: "Réglages d'apparence", spanish: "Ajustes de apariencia")
        case .advancedSettings:
            return localizedString(language, english: "Advanced Settings", chinese: "高级设置", italian: "Impostazioni avanzate", french: "Réglages avancés", spanish: "Ajustes avanzados")
        case .openMinecraftWiki:
            return localizedString(language, english: "Open Minecraft Wiki", chinese: "打开 Minecraft Wiki", italian: "Apri Minecraft Wiki", french: "Ouvrir Minecraft Wiki", spanish: "Abrir Minecraft Wiki")
        }
    }
}
