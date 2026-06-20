import Foundation

extension MinecraftVersionInstallDetailPage {
    var compatibleLoaders: [LoaderKind] {
        version.kind == .oldAlpha || version.kind == .oldBeta ? [] : LoaderKind.allCases
    }

    func selectLoader(_ candidate: LoaderKind?) {
        loaderVersion = nil
        shaderLoaderVersion = nil
        loader = candidate
        if !minecraftShaderLoaderCompatible(loader: candidate?.rawValue, shaderLoader: shaderLoader == .none ? nil : shaderLoader.rawValue) {
            shaderLoader = .none
        }
    }

    var shaderFallbackSummary: String? {
        guard
            let from = preflight?.shaderFallbackFrom,
            let to = preflight?.shaderFallbackTo
        else {
            return nil
        }
        return localizedString(
            theme.language,
            english: "Using compatible \(to) release because \(from) has no direct shader loader release.",
            chinese: "由于 \(from) 没有直接适配的光影加载器版本，将使用兼容的 \(to) release。",
            italian: "Uso release \(to) compatibile perché \(from) non ha una release diretta.",
            french: "Utilise la release \(to) compatible car \(from) n'a pas de release directe.",
            spanish: "Usando release compatible \(to) porque \(from) no tiene release directa."
        )
    }

    var installerProbeSummary: String? {
        guard let status = preflight?.installerProbeStatus, !status.isEmpty else {
            return nil
        }
        if status.hasPrefix("failed:") {
            return localizedString(
                theme.language,
                english: "Preflight could not fully probe the installer URL; install will still attempt the real download.",
                chinese: "预检未能完整探测安装器 URL；安装时仍会尝试真实下载。",
                italian: "Il preflight non ha verificato completamente l'URL installer; l'installazione tenterà comunque il download.",
                french: "Le précontrôle n'a pas entièrement testé l'URL de l'installateur ; l'installation tentera le téléchargement.",
                spanish: "La prevalidación no pudo verificar completamente la URL; la instalación intentará la descarga real."
            )
        }
        return status
    }

    var blockReason: String? {
        let trimmedName = instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return localizedString(theme.language, english: "Name this local instance before installing.", chinese: "安装前请为这个本地实例命名。", italian: "Assegna un nome all'istanza prima di installare.", french: "Nommez cette instance locale avant l'installation.", spanish: "Pon nombre a esta instancia local antes de instalar.")
        }
        if instances.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            return localizedString(theme.language, english: "An instance with this name already exists. Rename this one to keep data isolated.", chinese: "已有同名实例。请重命名，确保各实例数据隔离。", italian: "Esiste già un'istanza con questo nome.", french: "Une instance porte déjà ce nom.", spanish: "Ya existe una instancia con este nombre.")
        }
        if targetDirectoryConflictExists {
            return localizedString(theme.language, english: "This instance folder already exists. Choose another name or restore it from the local list.", chinese: "该实例目录已存在。请换一个名称，或从本地列表恢复它。", italian: "La cartella dell'istanza esiste già.", french: "Ce dossier d'instance existe déjà.", spanish: "Esta carpeta de instancia ya existe.")
        }
        if let loader, !compatibleLoaders.contains(loader) {
            return localizedString(theme.language, english: "\(loader.title) is not available for this version.", chinese: "\(loader.title) 不适用于该版本。", italian: "\(loader.title) non disponibile.", french: "\(loader.title) indisponible.", spanish: "\(loader.title) no disponible.")
        }
        if loader != nil, loaderVersion == nil {
            return localizedString(
                theme.language,
                english: "Choose an exact loader version before installing. Beta versions are never selected automatically.",
                chinese: "安装前请选择具体加载器版本。Beta 版本不会自动选择。",
                italian: "Scegli una versione precisa del loader prima di installare.",
                french: "Choisissez une version exacte du loader avant l'installation.",
                spanish: "Elige una version exacta del loader antes de instalar."
            )
        }
        if !selectedShaderLoaderIsCompatible {
            return localizedString(
                theme.language,
                english: "\(shaderLoader.title) cannot be installed with \(loader?.title ?? "Vanilla"). Choose a compatible shader loader or switch it to None.",
                chinese: "\(shaderLoader.title) 不能与 \(loader?.title ?? "Vanilla") 一起安装。请选择兼容的光影加载器，或切换为 None。",
                italian: "\(shaderLoader.title) non puo essere installato con \(loader?.title ?? "Vanilla").",
                french: "\(shaderLoader.title) ne peut pas etre installe avec \(loader?.title ?? "Vanilla").",
                spanish: "\(shaderLoader.title) no se puede instalar con \(loader?.title ?? "Vanilla")."
            )
        }
        if effectiveShaderLoader != nil, shaderLoaderVersion == nil {
            return localizedString(
                theme.language,
                english: "Choose an exact shader loader release before installing. Beta releases are never selected automatically.",
                chinese: "安装前请选择具体光影加载器版本。Beta 版本不会自动选择。",
                italian: "Scegli una release precisa del loader shader prima di installare.",
                french: "Choisissez une release exacte du loader de shaders avant l'installation.",
                spanish: "Elige una version exacta del loader de shaders antes de instalar."
            )
        }
        if let preflight, preflight.isBlocked {
            return localizedString(
                theme.language,
                english: preflight.displaySummary,
                chinese: preflight.displaySummary,
                italian: preflight.displaySummary,
                french: preflight.displaySummary,
                spanish: preflight.displaySummary
            )
        }
        return nil
    }

    var targetSummary: String {
        switch target {
        case .newConfiguration:
            let name = instanceDisplayName.isEmpty ? localizedString(theme.language, english: "manual name required", chinese: "需要手动命名", italian: "nome richiesto", french: "nom requis", spanish: "nombre requerido") : instanceDisplayName
            return localizedString(theme.language, english: "Create local instance \"\(name)\". Core verifies files before it appears in the local list.", chinese: "创建本地实例“\(name)”。Core 校验磁盘文件后会显示在本地列表。", italian: "Crea istanza locale \"\(name)\".", french: "Créer l'instance locale \"\(name)\".", spanish: "Crear instancia local \"\(name)\".")
        case .existingConfiguration:
            return localizedString(theme.language, english: "Existing-instance installs are disabled. Install a new local instance instead.", chinese: "已禁用覆盖当前实例安装。请安装为新的本地实例。", italian: "Installazione su istanza esistente disabilitata.", french: "Installation sur instance existante désactivée.", spanish: "Instalación sobre instancia existente desactivada.")
        case .downloadOnly:
            return localizedString(theme.language, english: "Download-only installs are disabled here. Installed files become a local instance.", chinese: "此处不再提供仅下载模式。安装后的文件会成为本地实例。", italian: "Solo download disabilitato.", french: "Téléchargement seul désactivé.", spanish: "Solo descarga desactivada.")
        }
    }

    var effectiveComponentSummary: String {
        [
            loader?.title ?? localizedString(theme.language, english: "Vanilla"),
            effectiveShaderLoader?.title
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    var javaRuntimePlanSummary: String {
        localizedString(
            theme.language,
            english: "\(version.javaRequirement) · Panino resolves from the Minecraft manifest and downloads the runtime inside the launcher when missing.",
            chinese: "\(version.javaRequirement) · Panino 会按 Minecraft 清单解析，缺失时在启动器内下载。",
            italian: "\(version.javaRequirement) · Panino risolve dal manifest Minecraft e scarica il runtime se manca.",
            french: "\(version.javaRequirement) · Panino résout depuis le manifeste Minecraft et télécharge le runtime si nécessaire.",
            spanish: "\(version.javaRequirement) · Panino resuelve desde el manifiesto de Minecraft y descarga el runtime si falta."
        )
    }

    var shaderHelpText: String {
        localizedString(
            theme.language,
            english: "Core installs Iris and Oculus as matching Modrinth mods. OptiFine requires a manual download if the upstream download is unavailable.",
            chinese: "Core 会将 Iris 和 Oculus 作为匹配的 Modrinth Mod 安装；若上游没有可用公开下载，OptiFine 需要手动安装。",
            italian: "Core installa Iris e Oculus da Modrinth. OptiFine può richiedere installazione manuale.",
            french: "Core installe Iris et Oculus depuis Modrinth. OptiFine peut nécessiter une installation manuelle.",
            spanish: "Core instala Iris y Oculus desde Modrinth. OptiFine puede requerir instalación manual."
        )
    }

    var loaderInstallNotice: String {
        localizedString(
            theme.language,
            english: "Core creates an isolated launch profile for the selected loader and records local instance metadata after installation.",
            chinese: "Core 会为所选 Loader 创建隔离的可启动 profile，并在安装后写入本地实例元数据。",
            italian: "Core crea un profilo isolato per il loader selezionato e salva i metadati locali.",
            french: "Core crée un profil isolé pour le loader choisi et enregistre les métadonnées locales.",
            spanish: "Core crea un perfil aislado para el loader seleccionado y guarda los metadatos locales."
        )
    }

    var installButtonTitle: String {
        switch target {
        case .newConfiguration:
            return localizedString(theme.language, english: "Install Local Instance", chinese: "安装本地实例", italian: "Installa istanza", french: "Installer l'instance", spanish: "Instalar instancia")
        case .existingConfiguration:
            return localizedString(theme.language, english: "Apply and Install", chinese: "应用并安装", italian: "Applica e installa", french: "Appliquer et installer", spanish: "Aplicar e instalar")
        case .downloadOnly:
            return localizedString(theme.language, english: "Download Files", chinese: "下载文件", italian: "Scarica file", french: "Télécharger fichiers", spanish: "Descargar archivos")
        }
    }

    var targetDirectoryLabel: String {
        targetDirectoryName.isEmpty
            ? localizedString(theme.language, english: "enter a name first", chinese: "请先输入名称", italian: "inserisci prima un nome", french: "saisissez d'abord un nom", spanish: "introduce primero un nombre")
            : "minecraft/versions/\(targetDirectoryName)"
    }

    func loaderChoiceState(_ candidate: LoaderKind?) -> InstallChoicePreflightState {
        let shader = minecraftShaderLoaderForPreflight(loader: candidate?.rawValue, shaderLoader: shaderLoader == .none ? nil : shaderLoader.rawValue)
        let result = choicePreflights[minecraftInstallChoiceKey(loader: candidate?.rawValue, shaderLoader: shader)]
        return installChoiceState(from: result, fallback: candidate == loader ? preflight : nil)
    }

    func shaderChoiceState(_ choice: ShaderLoaderChoice) -> InstallChoicePreflightState {
        if shaderChoiceDisabled(choice) {
            return .blocked
        }
        let shader = choice == .none ? nil : choice.rawValue
        let result = choicePreflights[minecraftInstallChoiceKey(loader: loader?.rawValue, shaderLoader: shader)]
        return installChoiceState(from: result, fallback: choice == shaderLoader ? preflight : nil)
    }

    func shaderChoiceDisabled(_ choice: ShaderLoaderChoice) -> Bool {
        choice != .none && !minecraftShaderLoaderCompatible(loader: loader?.rawValue, shaderLoader: choice.rawValue)
    }

    private var selectedShaderLoaderRawValue: String? {
        shaderLoader == .none ? nil : shaderLoader.rawValue
    }

    private var selectedShaderLoaderIsCompatible: Bool {
        minecraftShaderLoaderCompatible(loader: loader?.rawValue, shaderLoader: selectedShaderLoaderRawValue)
    }

    private var effectiveShaderLoader: ShaderLoaderChoice? {
        selectedShaderLoaderIsCompatible && shaderLoader != .none ? shaderLoader : nil
    }

    private var instanceDisplayName: String {
        instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var targetDirectoryName: String {
        instanceDisplayName.isEmpty ? "" : slug(instanceDisplayName)
    }

    private var targetDirectoryURL: URL {
        let root = (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
        return root.appendingPathComponent(targetDirectoryName, isDirectory: true)
    }

    private var targetDirectoryConflictExists: Bool {
        guard target == .newConfiguration else { return false }
        guard !targetDirectoryName.isEmpty else { return false }
        return minecraftInstallTargetDirectoryConflictExists(targetDirectoryURL)
    }

    private func installChoiceState(from result: CoreLoaderInstallPreflightResponse?, fallback: CoreLoaderInstallPreflightResponse?) -> InstallChoicePreflightState {
        let resolved = result ?? fallback
        if let resolved, hasChoiceCompatibilityBlocker(resolved) {
            return .blocked
        }
        if resolved?.isBlocked == true || resolved?.status == "warning" || resolved?.warnings.isEmpty == false {
            return .warning
        }
        return .normal
    }

    private func hasChoiceCompatibilityBlocker(_ preflight: CoreLoaderInstallPreflightResponse) -> Bool {
        preflight.blockedReasons.contains { reason in
            let normalized = reason.lowercased()
            return normalized.hasPrefix("loader_version_not_found")
                || normalized.hasPrefix("loader_profile_not_found")
                || normalized.hasPrefix("loader_profile_url_not_found")
                || normalized.hasPrefix("loader_installer_not_found")
                || normalized.hasPrefix("forge_installer_url_not_found")
                || normalized.hasPrefix("neoforge_installer_url_not_found")
                || normalized.hasPrefix("shader_loader_incompatible")
                || normalized.hasPrefix("shader_release_not_found")
                || normalized.hasPrefix("shader_dependency_unresolved")
        }
    }

    private func slug(_ value: String) -> String {
        var result = ""
        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return trimmed.isEmpty ? "minecraft-instance" : trimmed
    }
}
