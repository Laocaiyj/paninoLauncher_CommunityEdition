import SwiftUI

enum AppText {
    case launch
    case instances
    case versions
    case account
    case tasks
    case logs
    case appearance
    case settings
    case launchSubtitle
    case instancesSubtitle
    case versionsSubtitle
    case accountSubtitle
    case tasksSubtitle
    case logsSubtitle
    case appearanceSubtitle
    case settingsSubtitle
    case startCore
    case stopCore
    case language
    case mode
    case accent
    case preset
    case apply
    case glass
    case background
    case choose
    case softTexture
    case enabled
    case density
    case versionSelector
    case channel
    case loaderPlan
    case loader
    case loaderPlanDescription
    case contentManager
    case refresh
    case openFolder
    case type
    case noItems
    case deleteSelectedFile
    case deleteFile
    case cancel
    case released
    case java
    case download
    case verify
    case enable
    case disable
    case delete
    case status
    case details
    case instanceDetails
    case readyForTasks
    case coreLogs
    case export
    case clear
    case microsoftAccount
    case signedIn
    case restoring
    case waiting
    case error
    case signedOut
    case ready
    case attention
    case failed
    case downloading
    case running
    case idle
    case openMicrosoft

    func localized(_ language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            return chineseSimplified
        case .english:
            return english
        case .italian:
            return italian
        case .french:
            return french
        case .spanish:
            return spanish
        }
    }

    func localized(_ language: AppLanguage, _ value: String) -> String {
        localized(language).replacingOccurrences(of: "%@", with: value)
    }

    private var english: String {
        switch self {
        case .launch: return "Launch"
        case .instances: return "Local Instances"
        case .versions: return "Versions"
        case .account: return "Account"
        case .tasks: return "Tasks"
        case .logs: return "Logs"
        case .appearance: return "Appearance"
        case .settings: return "Settings"
        case .launchSubtitle: return "Current local instance launch center with checks, resources and task feedback."
        case .instancesSubtitle: return "Manage Minecraft instances already installed on disk."
        case .versionsSubtitle: return "Inspect versions, loaders, mods, resource packs and shaders."
        case .accountSubtitle: return "Manage Microsoft sign-in for launch sessions."
        case .tasksSubtitle: return "Track install, launch and download tasks."
        case .logsSubtitle: return "Inspect local launcher and Core output."
        case .appearanceSubtitle: return "Tune theme, material and background settings."
        case .settingsSubtitle: return "Configure launcher behavior, Java, Minecraft, downloads and diagnostics."
        case .startCore: return "Start Core"
        case .stopCore: return "Stop Core"
        case .language: return "Language"
        case .mode: return "Mode"
        case .accent: return "Accent"
        case .preset: return "Preset"
        case .apply: return "Apply"
        case .glass: return "Glass"
        case .background: return "Background"
        case .choose: return "Choose"
        case .softTexture: return "Soft Texture"
        case .enabled: return "Enabled"
        case .density: return "Density"
        case .versionSelector: return "Version Selector"
        case .channel: return "Channel"
        case .loaderPlan: return "Loader Plan"
        case .loader: return "Loader"
        case .loaderPlanDescription: return "Fabric, Quilt, Forge, and NeoForge are tracked here as planned loader targets. Install integration can be wired to the downloader in a later phase."
        case .contentManager: return "Content Manager"
        case .refresh: return "Refresh"
        case .openFolder: return "Open Folder"
        case .type: return "Type"
        case .noItems: return "No %@"
        case .deleteSelectedFile: return "Delete selected file?"
        case .deleteFile: return "Delete File"
        case .cancel: return "Cancel"
        case .released: return "Released"
        case .java: return "Java"
        case .download: return "Download"
        case .verify: return "Verify"
        case .enable: return "Enable"
        case .disable: return "Disable"
        case .delete: return "Delete"
        case .status: return "Status"
        case .details: return "Details"
        case .instanceDetails: return "Game Configuration Details"
        case .readyForTasks: return "Ready for tasks"
        case .coreLogs: return "Core Logs"
        case .export: return "Export"
        case .clear: return "Clear"
        case .microsoftAccount: return "Microsoft Account"
        case .signedIn: return "Signed In"
        case .restoring: return "Restoring"
        case .waiting: return "Waiting"
        case .error: return "Error"
        case .signedOut: return "Signed Out"
        case .ready: return "Ready"
        case .attention: return "Attention"
        case .failed: return "Failed"
        case .downloading: return "Downloading"
        case .running: return "Running"
        case .idle: return "Idle"
        case .openMicrosoft: return "Open Microsoft"
        }
    }

    private var chineseSimplified: String {
        switch self {
        case .launch: return "启动"
        case .instances: return "本地实例"
        case .versions: return "版本"
        case .account: return "账号"
        case .tasks: return "任务"
        case .logs: return "日志"
        case .appearance: return "外观"
        case .settings: return "设置"
        case .launchSubtitle: return "当前本地实例启动中心，包含检查、资源与任务反馈。"
        case .instancesSubtitle: return "管理已经安装到本地磁盘的 Minecraft 实例。"
        case .versionsSubtitle: return "查看版本、加载器、Mod、资源包和光影包。"
        case .accountSubtitle: return "管理用于启动游戏的 Microsoft 登录。"
        case .tasksSubtitle: return "跟踪安装、启动和下载任务。"
        case .logsSubtitle: return "查看启动器和 Core 输出。"
        case .appearanceSubtitle: return "调整主题、材质和背景设置。"
        case .settingsSubtitle: return "配置启动器行为、Java、Minecraft、下载和诊断。"
        case .startCore: return "启动 Core"
        case .stopCore: return "停止 Core"
        case .language: return "语言"
        case .mode: return "模式"
        case .accent: return "强调色"
        case .preset: return "预设"
        case .apply: return "应用"
        case .glass: return "玻璃"
        case .background: return "背景"
        case .choose: return "选择"
        case .softTexture: return "柔和纹理"
        case .enabled: return "启用"
        case .density: return "密度"
        case .versionSelector: return "版本选择器"
        case .channel: return "通道"
        case .loaderPlan: return "加载器规划"
        case .loader: return "加载器"
        case .loaderPlanDescription: return "Fabric、Quilt、Forge 和 NeoForge 会作为规划中的加载器目标展示，后续可接入下载器安装流程。"
        case .contentManager: return "内容管理"
        case .refresh: return "刷新"
        case .openFolder: return "打开文件夹"
        case .type: return "类型"
        case .noItems: return "没有%@"
        case .deleteSelectedFile: return "删除选中的文件？"
        case .deleteFile: return "删除文件"
        case .cancel: return "取消"
        case .released: return "发布时间"
        case .java: return "Java"
        case .download: return "下载"
        case .verify: return "校验"
        case .enable: return "启用"
        case .disable: return "禁用"
        case .delete: return "删除"
        case .status: return "状态"
        case .details: return "详情"
        case .instanceDetails: return "游戏配置详情"
        case .readyForTasks: return "任务就绪"
        case .coreLogs: return "Core 日志"
        case .export: return "导出"
        case .clear: return "清空"
        case .microsoftAccount: return "Microsoft 账号"
        case .signedIn: return "已登录"
        case .restoring: return "正在恢复"
        case .waiting: return "等待中"
        case .error: return "错误"
        case .signedOut: return "未登录"
        case .ready: return "就绪"
        case .attention: return "注意"
        case .failed: return "失败"
        case .downloading: return "下载中"
        case .running: return "运行中"
        case .idle: return "空闲"
        case .openMicrosoft: return "打开 Microsoft"
        }
    }

    private var italian: String {
        switch self {
        case .launch: return "Avvio"
        case .instances: return "Istanze locali"
        case .versions: return "Versioni"
        case .account: return "Account"
        case .tasks: return "Attività"
        case .logs: return "Log"
        case .appearance: return "Aspetto"
        case .settings: return "Impostazioni"
        case .launchSubtitle: return "Centro avvio dell'istanza locale con controlli, risorse e attività."
        case .instancesSubtitle: return "Gestisci le istanze Minecraft già installate sul disco."
        case .versionsSubtitle: return "Controlla versioni, loader, mod, resource pack e shader."
        case .accountSubtitle: return "Gestisci l'accesso Microsoft per le sessioni di avvio."
        case .tasksSubtitle: return "Monitora installazioni, avvii e download."
        case .logsSubtitle: return "Controlla l'output del launcher e del Core."
        case .appearanceSubtitle: return "Regola tema, materiali e sfondo."
        case .settingsSubtitle: return "Configura launcher, Java, Minecraft, download e diagnostica."
        case .startCore: return "Avvia Core"
        case .stopCore: return "Ferma Core"
        case .language: return "Lingua"
        case .mode: return "Modalità"
        case .accent: return "Accento"
        case .preset: return "Preset"
        case .apply: return "Applica"
        case .glass: return "Vetro"
        case .background: return "Sfondo"
        case .choose: return "Scegli"
        case .softTexture: return "Texture morbida"
        case .enabled: return "Attiva"
        case .density: return "Densità"
        case .versionSelector: return "Selettore versione"
        case .channel: return "Canale"
        case .loaderPlan: return "Piano loader"
        case .loader: return "Loader"
        case .loaderPlanDescription: return "Fabric, Quilt, Forge e NeoForge sono tracciati come loader pianificati. L'installazione potrà essere collegata al downloader."
        case .contentManager: return "Gestione contenuti"
        case .refresh: return "Aggiorna"
        case .openFolder: return "Apri cartella"
        case .type: return "Tipo"
        case .noItems: return "Nessun %@"
        case .deleteSelectedFile: return "Eliminare il file selezionato?"
        case .deleteFile: return "Elimina file"
        case .cancel: return "Annulla"
        case .released: return "Rilasciato"
        case .java: return "Java"
        case .download: return "Download"
        case .verify: return "Verifica"
        case .enable: return "Attiva"
        case .disable: return "Disattiva"
        case .delete: return "Elimina"
        case .status: return "Stato"
        case .details: return "Dettagli"
        case .instanceDetails: return "Dettagli configurazione"
        case .readyForTasks: return "Pronto per le attività"
        case .coreLogs: return "Log Core"
        case .export: return "Esporta"
        case .clear: return "Pulisci"
        case .microsoftAccount: return "Account Microsoft"
        case .signedIn: return "Connesso"
        case .restoring: return "Ripristino"
        case .waiting: return "In attesa"
        case .error: return "Errore"
        case .signedOut: return "Disconnesso"
        case .ready: return "Pronto"
        case .attention: return "Attenzione"
        case .failed: return "Fallito"
        case .downloading: return "Download"
        case .running: return "In esecuzione"
        case .idle: return "Inattivo"
        case .openMicrosoft: return "Apri Microsoft"
        }
    }

    private var french: String {
        switch self {
        case .launch: return "Lancer"
        case .instances: return "Instances locales"
        case .versions: return "Versions"
        case .account: return "Compte"
        case .tasks: return "Tâches"
        case .logs: return "Journaux"
        case .appearance: return "Apparence"
        case .settings: return "Réglages"
        case .launchSubtitle: return "Centre de lancement de l'instance locale avec vérifications, ressources et tâches."
        case .instancesSubtitle: return "Gérez les instances Minecraft déjà installées sur le disque."
        case .versionsSubtitle: return "Consultez versions, chargeurs, mods, packs et shaders."
        case .accountSubtitle: return "Gérez la connexion Microsoft pour les sessions de lancement."
        case .tasksSubtitle: return "Suivez les installations, lancements et téléchargements."
        case .logsSubtitle: return "Inspectez la sortie du lanceur et du Core."
        case .appearanceSubtitle: return "Ajustez le thème, les matériaux et l'arrière-plan."
        case .settingsSubtitle: return "Configurez lanceur, Java, Minecraft, téléchargements et diagnostics."
        case .startCore: return "Démarrer Core"
        case .stopCore: return "Arrêter Core"
        case .language: return "Langue"
        case .mode: return "Mode"
        case .accent: return "Accent"
        case .preset: return "Préréglage"
        case .apply: return "Appliquer"
        case .glass: return "Verre"
        case .background: return "Arrière-plan"
        case .choose: return "Choisir"
        case .softTexture: return "Texture douce"
        case .enabled: return "Activé"
        case .density: return "Densité"
        case .versionSelector: return "Sélecteur de version"
        case .channel: return "Canal"
        case .loaderPlan: return "Plan des chargeurs"
        case .loader: return "Chargeur"
        case .loaderPlanDescription: return "Fabric, Quilt, Forge et NeoForge sont suivis comme chargeurs prévus. L'installation pourra être reliée au téléchargeur."
        case .contentManager: return "Gestion du contenu"
        case .refresh: return "Actualiser"
        case .openFolder: return "Ouvrir le dossier"
        case .type: return "Type"
        case .noItems: return "Aucun %@"
        case .deleteSelectedFile: return "Supprimer le fichier sélectionné ?"
        case .deleteFile: return "Supprimer le fichier"
        case .cancel: return "Annuler"
        case .released: return "Sortie"
        case .java: return "Java"
        case .download: return "Téléchargement"
        case .verify: return "Vérification"
        case .enable: return "Activer"
        case .disable: return "Désactiver"
        case .delete: return "Supprimer"
        case .status: return "État"
        case .details: return "Détails"
        case .instanceDetails: return "Détails de la configuration"
        case .readyForTasks: return "Prêt pour les tâches"
        case .coreLogs: return "Journaux Core"
        case .export: return "Exporter"
        case .clear: return "Effacer"
        case .microsoftAccount: return "Compte Microsoft"
        case .signedIn: return "Connecté"
        case .restoring: return "Restauration"
        case .waiting: return "En attente"
        case .error: return "Erreur"
        case .signedOut: return "Déconnecté"
        case .ready: return "Prêt"
        case .attention: return "Attention"
        case .failed: return "Échec"
        case .downloading: return "Téléchargement"
        case .running: return "En cours"
        case .idle: return "Inactif"
        case .openMicrosoft: return "Ouvrir Microsoft"
        }
    }

    private var spanish: String {
        switch self {
        case .launch: return "Iniciar"
        case .instances: return "Instancias locales"
        case .versions: return "Versiones"
        case .account: return "Cuenta"
        case .tasks: return "Tareas"
        case .logs: return "Registros"
        case .appearance: return "Apariencia"
        case .settings: return "Ajustes"
        case .launchSubtitle: return "Centro de inicio de la instancia local con comprobaciones, recursos y tareas."
        case .instancesSubtitle: return "Gestiona las instancias de Minecraft ya instaladas en el disco."
        case .versionsSubtitle: return "Revisa versiones, loaders, mods, recursos y shaders."
        case .accountSubtitle: return "Gestiona el inicio de sesión de Microsoft."
        case .tasksSubtitle: return "Supervisa instalaciones, inicios y descargas."
        case .logsSubtitle: return "Revisa la salida del launcher y del Core."
        case .appearanceSubtitle: return "Ajusta el tema, los materiales y el fondo."
        case .settingsSubtitle: return "Configura launcher, Java, Minecraft, descargas y diagnóstico."
        case .startCore: return "Iniciar Core"
        case .stopCore: return "Detener Core"
        case .language: return "Idioma"
        case .mode: return "Modo"
        case .accent: return "Acento"
        case .preset: return "Preajuste"
        case .apply: return "Aplicar"
        case .glass: return "Cristal"
        case .background: return "Fondo"
        case .choose: return "Elegir"
        case .softTexture: return "Textura suave"
        case .enabled: return "Activado"
        case .density: return "Densidad"
        case .versionSelector: return "Selector de versión"
        case .channel: return "Canal"
        case .loaderPlan: return "Plan de loaders"
        case .loader: return "Loader"
        case .loaderPlanDescription: return "Fabric, Quilt, Forge y NeoForge se registran como loaders previstos. La instalación podrá conectarse al descargador."
        case .contentManager: return "Gestor de contenido"
        case .refresh: return "Actualizar"
        case .openFolder: return "Abrir carpeta"
        case .type: return "Tipo"
        case .noItems: return "Sin %@"
        case .deleteSelectedFile: return "¿Eliminar el archivo seleccionado?"
        case .deleteFile: return "Eliminar archivo"
        case .cancel: return "Cancelar"
        case .released: return "Publicado"
        case .java: return "Java"
        case .download: return "Descarga"
        case .verify: return "Verificar"
        case .enable: return "Activar"
        case .disable: return "Desactivar"
        case .delete: return "Eliminar"
        case .status: return "Estado"
        case .details: return "Detalles"
        case .instanceDetails: return "Detalles de configuración"
        case .readyForTasks: return "Listo para tareas"
        case .coreLogs: return "Registros Core"
        case .export: return "Exportar"
        case .clear: return "Limpiar"
        case .microsoftAccount: return "Cuenta Microsoft"
        case .signedIn: return "Conectado"
        case .restoring: return "Restaurando"
        case .waiting: return "Esperando"
        case .error: return "Error"
        case .signedOut: return "Desconectado"
        case .ready: return "Listo"
        case .attention: return "Atención"
        case .failed: return "Fallido"
        case .downloading: return "Descargando"
        case .running: return "En ejecución"
        case .idle: return "Inactivo"
        case .openMicrosoft: return "Abrir Microsoft"
        }
    }
}
