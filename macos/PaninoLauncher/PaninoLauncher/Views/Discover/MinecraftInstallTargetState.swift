import Foundation

extension MinecraftVersionInstallDetailPage {
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
