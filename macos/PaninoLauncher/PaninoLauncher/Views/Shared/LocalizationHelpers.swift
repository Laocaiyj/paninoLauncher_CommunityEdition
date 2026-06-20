import Foundation

func localizedString(_ language: AppLanguage, english: String) -> String {
    AutoLocalizationCatalog.localized(english, language: language)
}

func localizedString(
    _ language: AppLanguage,
    english: String,
    chinese: String,
    italian: String,
    french: String,
    spanish: String
) -> String {
    switch language {
    case .chineseSimplified:
        return chinese
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

private enum AutoLocalizationCatalog {
    private static let zhHans = AppLanguage.chineseSimplified.rawValue
    private static let it = AppLanguage.italian.rawValue
    private static let fr = AppLanguage.french.rawValue
    private static let es = AppLanguage.spanish.rawValue

    private static let terms: [String: [String: String]] = [
        "Active": [zhHans: "当前", it: "Attivo", fr: "Actif", es: "Activa"],
        "All": [zhHans: "全部", it: "Tutte", fr: "Toutes", es: "Todas"],
        "Available": [zhHans: "可用", it: "Disponibile", fr: "Disponible", es: "Disponible"],
        "Back": [zhHans: "返回", it: "Indietro", fr: "Retour", es: "Volver"],
        "Content": [zhHans: "内容", it: "Contenuto", fr: "Contenu", es: "Contenido"],
        "Core connected": [zhHans: "Core 已连接", it: "Core connesso", fr: "Core connecté", es: "Core conectado"],
        "Core failed": [zhHans: "Core 失败", it: "Errore Core", fr: "Échec Core", es: "Error de Core"],
        "Core stopped": [zhHans: "Core 已停止", it: "Core fermo", fr: "Core arrêté", es: "Core detenido"],
        "Default": [zhHans: "默认", it: "Predefinito", fr: "Par défaut", es: "Predeterminado"],
        "Details": [zhHans: "详情", it: "Dettagli", fr: "Détails", es: "Detalles"],
        "Directory": [zhHans: "目录", it: "Cartella", fr: "Dossier", es: "Directorio"],
        "Download": [zhHans: "下载", it: "Download", fr: "Téléchargement", es: "Descarga"],
        "Failed": [zhHans: "失败", it: "Fallita", fr: "Échec", es: "Fallida"],
        "Favorite": [zhHans: "收藏", it: "Preferito", fr: "Favori", es: "Favorito"],
        "Favorites": [zhHans: "收藏", it: "Preferiti", fr: "Favoris", es: "Favoritos"],
        "Files": [zhHans: "文件", it: "File", fr: "Fichiers", es: "Archivos"],
        "Global": [zhHans: "全局", it: "Globale", fr: "Global", es: "Global"],
        "Idle": [zhHans: "空闲", it: "Inattivo", fr: "Inactif", es: "Inactivo"],
        "Install": [zhHans: "安装", it: "Installa", fr: "Installer", es: "Instalar"],
        "Installed": [zhHans: "已安装", it: "Installata", fr: "Installée", es: "Instalada"],
        "Java": [zhHans: "Java", it: "Java", fr: "Java", es: "Java"],
        "Last Launch": [zhHans: "最近启动", it: "Ultimo avvio", fr: "Dernier lancement", es: "Último inicio"],
        "Loader": [zhHans: "加载器", it: "Loader", fr: "Loader", es: "Loader"],
        "Local": [zhHans: "本地", it: "Locale", fr: "Local", es: "Local"],
        "Memory": [zhHans: "内存", it: "Memoria", fr: "Mémoire", es: "Memoria"],
        "Missing Files": [zhHans: "缺少文件", it: "File mancanti", fr: "Fichiers manquants", es: "Faltan archivos"],
        "Mods": [zhHans: "Mod", it: "Mod", fr: "Mods", es: "Mods"],
        "Name": [zhHans: "名称", it: "Nome", fr: "Nom", es: "Nombre"],
        "Needs Attention": [zhHans: "需要处理", it: "Da verificare", fr: "À traiter", es: "Requieren atención"],
        "Needs Install": [zhHans: "需要安装", it: "Da installare", fr: "À installer", es: "Falta instalar"],
        "Never": [zhHans: "从未", it: "Mai", fr: "Jamais", es: "Nunca"],
        "None": [zhHans: "无", it: "Nessuno", fr: "Aucun", es: "Ninguno"],
        "Offline fallback": [zhHans: "离线回退", it: "Fallback offline", fr: "Mode hors ligne", es: "Modo offline"],
        "Open": [zhHans: "打开", it: "Apri", fr: "Ouvrir", es: "Abrir"],
        "Open Folder": [zhHans: "打开文件夹", it: "Apri cartella", fr: "Ouvrir dossier", es: "Abrir carpeta"],
        "Play Time": [zhHans: "游戏时长", it: "Tempo gioco", fr: "Temps de jeu", es: "Tiempo jugado"],
        "Ready": [zhHans: "可启动", it: "Pronto", fr: "Prêt", es: "Listo"],
        "Release": [zhHans: "正式版", it: "Release", fr: "Release", es: "Release"],
        "Resource Pack": [zhHans: "资源包", it: "Resource pack", fr: "Pack de ressources", es: "Paquete de recursos"],
        "Resource Packs": [zhHans: "资源包", it: "Pacchetti risorse", fr: "Packs de ressources", es: "Paquetes de recursos"],
        "Running": [zhHans: "运行中", it: "In esecuzione", fr: "En cours", es: "En ejecución"],
        "Search": [zhHans: "搜索", it: "Cerca", fr: "Rechercher", es: "Buscar"],
        "Shader Pack": [zhHans: "光影包", it: "Shader pack", fr: "Pack de shaders", es: "Paquete de shaders"],
        "Shader Packs": [zhHans: "光影包", it: "Shader pack", fr: "Packs de shaders", es: "Paquetes de shaders"],
        "Snapshot": [zhHans: "快照版", it: "Snapshot", fr: "Snapshot", es: "Snapshot"],
        "Sort": [zhHans: "排序", it: "Ordina", fr: "Tri", es: "Orden"],
        "Starting Core": [zhHans: "正在启动 Core", it: "Avvio Core", fr: "Démarrage Core", es: "Iniciando Core"],
        "Status": [zhHans: "状态", it: "Stato", fr: "État", es: "Estado"],
        "Stopping Core": [zhHans: "正在停止 Core", it: "Arresto Core", fr: "Arrêt Core", es: "Deteniendo Core"],
        "Updated": [zhHans: "更新", it: "Aggiornato", fr: "Mis à jour", es: "Actualizado"],
        "Unknown": [zhHans: "未知", it: "Sconosciuto", fr: "Inconnu", es: "Desconocido"],
        "Used by Config": [zhHans: "配置使用中", it: "Usata", fr: "Utilisée", es: "En uso"],
        "Vanilla": [zhHans: "原版", it: "Vanilla", fr: "Vanilla", es: "Vanilla"],
        "Verify": [zhHans: "校验", it: "Verifica", fr: "Vérifier", es: "Verificar"],
        "Version": [zhHans: "版本", it: "Versione", fr: "Version", es: "Versión"]
    ]

    static func localized(_ englishText: String, language: AppLanguage) -> String {
        guard language != .english else { return englishText }
        let trimmed = englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = terms[trimmed]?[language.rawValue] {
            return direct
        }

        if trimmed.contains(" · ") {
            return trimmed
                .components(separatedBy: " · ")
                .map { localized($0, language: language) }
                .joined(separator: " · ")
        }

        if trimmed.hasPrefix("Minecraft ") {
            return trimmed
        }

        if let suffix = trimmed.removingPrefix("Version ") {
            return joinPrefix("Version", suffix: suffix, language: language)
        }

        if let suffix = trimmed.removingPrefix("Updated ") {
            return joinPrefix("Updated", suffix: suffix, language: language)
        }

        if let suffix = trimmed.removingPrefix("Install ") {
            return joinPrefix("Install", suffix: suffix, language: language)
        }

        if let suffix = trimmed.removingPrefix("Open ") {
            return joinPrefix("Open", suffix: suffix, language: language)
        }

        if let range = trimmed.range(of: #"^(\d+)-(\d+) of (\d+) versions$"#, options: .regularExpression) {
            let match = String(trimmed[range])
            let parts = match
                .replacingOccurrences(of: " of ", with: " ")
                .replacingOccurrences(of: " versions", with: "")
                .split(separator: " ")
            if parts.count == 2 {
                switch language {
                case .chineseSimplified:
                    return "第 \(parts[0]) 个，共 \(parts[1]) 个版本"
                case .italian:
                    return "\(parts[0]) di \(parts[1]) versioni"
                case .french:
                    return "\(parts[0]) sur \(parts[1]) versions"
                case .spanish:
                    return "\(parts[0]) de \(parts[1]) versiones"
                case .english:
                    return englishText
                }
            }
        }

        return englishText
    }

    private static func joinPrefix(_ prefix: String, suffix: String, language: AppLanguage) -> String {
        switch (prefix, language) {
        case ("Version", .chineseSimplified):
            return "版本 \(suffix)"
        case ("Updated", .chineseSimplified):
            return "更新于 \(suffix)"
        case ("Install", .chineseSimplified):
            return "安装 \(suffix)"
        case ("Open", .chineseSimplified):
            return "打开 \(suffix)"
        case ("Updated", .italian):
            return "Aggiornato \(suffix)"
        case ("Updated", .french):
            return "Mis à jour \(suffix)"
        case ("Updated", .spanish):
            return "Actualizado \(suffix)"
        default:
            return "\(terms[prefix]?[language.rawValue] ?? prefix) \(suffix)"
        }
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
