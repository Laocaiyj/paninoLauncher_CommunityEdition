import Foundation

enum InstanceCreationWizardPresentation {
    static func stepTitle(language: AppLanguage, step: InstanceCreationStep) -> String {
        switch step {
        case .source:
            return localizedString(language, english: "Purpose", chinese: "用途", italian: "Uso", french: "Usage", spanish: "Uso")
        case .version:
            return localizedString(language, english: "Version & Loader", chinese: "版本与 Loader", italian: "Versione e loader", french: "Version et loader", spanish: "Versión y loader")
        case .review:
            return localizedString(language, english: "Review", chinese: "预检查", italian: "Revisione", french: "Vérification", spanish: "Revisión")
        }
    }

    static func sourceHelpText(language: AppLanguage, source: String) -> String {
        switch source {
        case "Mod Configuration":
            return localizedString(language, english: "Panino will recommend a loader and keep Java, memory and folders automatic unless you open More Options.", chinese: "Panino 会推荐加载器，并自动处理 Java、内存和目录；需要时可在“更多选项”中修改。", italian: "Panino consiglia un loader e automatizza runtime e cartelle.", french: "Panino recommande un loader et automatise Java, mémoire et dossiers.", spanish: "Panino recomienda un loader y automatiza Java, memoria y carpetas.")
        case "Import Modpack":
            return localizedString(language, english: "Modpack import will not create an empty configuration. Choose a pack source first, then Core creates the target after preflight.", chinese: "整合包导入不会创建空配置。先选择整合包来源，Core 预检通过后再创建目标配置。", italian: "L'import modpack non crea configurazioni vuote.", french: "L'import de modpack ne crée pas de configuration vide.", spanish: "Importar modpacks no crea configuraciones vacías.")
        default:
            return localizedString(language, english: "Create a clean Vanilla game configuration with automatic Java, memory and folder defaults.", chinese: "创建一个干净的原版游戏配置，Java、内存和目录默认自动处理。", italian: "Crea una configurazione Vanilla con impostazioni automatiche.", french: "Créer une configuration Vanilla avec réglages automatiques.", spanish: "Crear una configuración Vanilla con ajustes automáticos.")
        }
    }

    static func generatedName(
        language: AppLanguage,
        draft: InstanceCreationDraft,
        modpackPreflight: CoreModpackPreflightResponse?
    ) -> String {
        if draft.source == "Mod Configuration" {
            return "\(draft.loader?.title ?? "Fabric") \(draft.minecraftVersion)"
        }
        if draft.source == "Import Modpack" {
            return modpackPreflight?.name ?? localizedString(language, english: "Imported Modpack", chinese: "导入整合包", italian: "Modpack importato", french: "Modpack importé", spanish: "Modpack importado")
        }
        return "Minecraft \(draft.minecraftVersion)"
    }

    static func shouldRegenerateName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            || trimmed == "New Game Configuration"
            || trimmed.hasPrefix("Minecraft ")
            || trimmed.hasPrefix("Fabric ")
            || trimmed.hasPrefix("Forge ")
            || trimmed.hasPrefix("Quilt ")
            || trimmed.hasPrefix("NeoForge ")
    }

    static func versionPickerMatches(
        versions: [MinecraftVersionInfo],
        latestReleaseID: String?,
        selectedVersionID: String,
        searchText: String
    ) -> [MinecraftVersionInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let recommended = recommendedVersions(
            versions: versions,
            latestReleaseID: latestReleaseID,
            selectedVersionID: selectedVersionID
        )
        let base = query.isEmpty
            ? uniqueVersions(
                recommended
                    + Array(versions.filter { $0.kind == .release }.prefix(80))
                    + versions.filter(\.isUsedByInstance)
              )
            : versions.filter { $0.id.localizedCaseInsensitiveContains(query) }
        return uniqueVersions(base).sorted { lhs, rhs in
            if !query.isEmpty {
                let lowerQuery = query.lowercased()
                let lhsExact = lhs.id.caseInsensitiveCompare(query) == .orderedSame
                let rhsExact = rhs.id.caseInsensitiveCompare(query) == .orderedSame
                if lhsExact != rhsExact { return lhsExact && !rhsExact }
                let lhsPrefix = lhs.id.lowercased().hasPrefix(lowerQuery)
                let rhsPrefix = rhs.id.lowercased().hasPrefix(lowerQuery)
                if lhsPrefix != rhsPrefix { return lhsPrefix && !rhsPrefix }
            }
            if lhs.isUsedByInstance != rhs.isUsedByInstance {
                return lhs.isUsedByInstance && !rhs.isUsedByInstance
            }
            if lhs.isInstalled != rhs.isInstalled {
                return lhs.isInstalled && !rhs.isInstalled
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedDescending
        }
    }

    static func loaderStatusText(
        language: AppLanguage,
        isLoadingLoaders: Bool,
        loaderStatus: String,
        availableLoaderOptions: [LoaderCompatibilityOption]
    ) -> String {
        if isLoadingLoaders {
            return localizedString(language, english: "Loading Loader compatibility from Core...", chinese: "正在从 Core 加载 Loader 兼容性...", italian: "Caricamento compatibilità loader dal Core...", french: "Chargement compatibilité loader depuis Core...", spanish: "Cargando compatibilidad del loader desde Core...")
        }
        if availableLoaderOptions.isEmpty {
            return localizedString(language, english: loaderStatus, chinese: loaderStatus, italian: loaderStatus, french: loaderStatus, spanish: loaderStatus)
        }
        let names = availableLoaderOptions.map(\.kind.title).joined(separator: ", ")
        return localizedString(language, english: "Core reports compatible loaders: \(names).", chinese: "Core 返回的可用 Loader：\(names)。", italian: "Loader compatibili dal Core: \(names).", french: "Loaders compatibles Core : \(names).", spanish: "Loaders compatibles de Core: \(names).")
    }

    static func loaderReviewText(draft: InstanceCreationDraft) -> String {
        guard let loader = draft.loader else { return "Vanilla" }
        return [loader.title, draft.loaderVersion].compactMap { $0 }.joined(separator: " · ")
    }

    static func installPlanSummary(language: AppLanguage, draft: InstanceCreationDraft, loaderReviewText: String) -> String {
        switch draft.source {
        case "Mod Configuration":
            return localizedString(language, english: "Install Minecraft files, install \(loaderReviewText), then open the Mods page.", chinese: "安装 Minecraft 文件，安装 \(loaderReviewText)，然后进入 Mods 页。", italian: "Installa Minecraft e \(loaderReviewText), poi apri Mods.", french: "Installer Minecraft et \(loaderReviewText), puis ouvrir Mods.", spanish: "Instalar Minecraft y \(loaderReviewText), luego abrir Mods.")
        case "Import Modpack":
            return draft.modpackSource == "Online"
                ? localizedString(language, english: "Open the Get page and select a modpack before Core creates a configuration.", chinese: "打开“获取”页选择整合包，Core 预检后再创建配置。", italian: "Apri Ottieni e seleziona un modpack.", french: "Ouvrir Obtenir et sélectionner un modpack.", spanish: "Abrir Obtener y elegir un modpack.")
                : localizedString(language, english: "Local modpack path will be parsed by Core before any configuration is created.", chinese: "本地整合包路径会先由 Core 解析，之后才创建配置。", italian: "Il file locale sarà analizzato dal Core.", french: "Le fichier local sera analysé par Core.", spanish: "Core analizará el archivo local.")
        default:
            return localizedString(language, english: "Install Minecraft files and create a Vanilla configuration.", chinese: "安装 Minecraft 文件并创建原版配置。", italian: "Installa Minecraft e crea Vanilla.", french: "Installer Minecraft et créer Vanilla.", spanish: "Instalar Minecraft y crear Vanilla.")
        }
    }

    static func primaryActionTitle(language: AppLanguage, draft: InstanceCreationDraft) -> String {
        if draft.source == "Import Modpack" {
            return draft.modpackSource == "Online"
                ? localizedString(language, english: "Open Import", chinese: "打开导入", italian: "Apri import", french: "Ouvrir import", spanish: "Abrir importación")
                : localizedString(language, english: "Create from Pack", chinese: "从整合包创建", italian: "Crea da pack", french: "Créer depuis pack", spanish: "Crear desde pack")
        }
        return localizedString(language, english: "Create & Install", chinese: "创建并安装", italian: "Crea e installa", french: "Créer et installer", spanish: "Crear e instalar")
    }

    static func primaryActionIcon(source: String) -> String {
        source == "Import Modpack" ? "arrow.down.app" : "checkmark.circle"
    }

    static func modpackPreflightSummary(
        language: AppLanguage,
        isCheckingModpack: Bool,
        status: String,
        modpackPreflight: CoreModpackPreflightResponse?
    ) -> String {
        if isCheckingModpack {
            return localizedString(language, english: "Core is checking the modpack...", chinese: "Core 正在检查整合包...", italian: "Core controlla il modpack...", french: "Core vérifie le modpack...", spanish: "Core revisa el modpack...")
        }
        if !status.isEmpty {
            return status
        }
        if let modpackPreflight {
            if modpackPreflight.valid {
                return localizedString(
                    language,
                    english: "\(modpackPreflight.minecraftVersion ?? "Unknown") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mods",
                    chinese: "\(modpackPreflight.minecraftVersion ?? "未知版本") · \(modpackPreflight.loader ?? "原版") · \(modpackPreflight.modCount) 个 Mod",
                    italian: "\(modpackPreflight.minecraftVersion ?? "Sconosciuta") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mod",
                    french: "\(modpackPreflight.minecraftVersion ?? "Inconnue") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mods",
                    spanish: "\(modpackPreflight.minecraftVersion ?? "Desconocida") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mods"
                )
            }
            return modpackPreflight.blockingReasons.joined(separator: ", ")
        }
        return localizedString(language, english: "Preflight required before creating a local modpack configuration.", chinese: "创建本地整合包配置前需要先预检。", italian: "Preflight richiesto.", french: "Précontrôle requis.", spanish: "Preflight requerido.")
    }

    private static func recommendedVersions(
        versions: [MinecraftVersionInfo],
        latestReleaseID: String?,
        selectedVersionID: String
    ) -> [MinecraftVersionInfo] {
        uniqueVersions(
            versions.filter { $0.id == selectedVersionID }
                + versions.filter { $0.id == latestReleaseID }
                + versions.filter(\.isInstalled)
                + Array(versions.filter { $0.kind == .release }.prefix(8))
        )
    }
}
