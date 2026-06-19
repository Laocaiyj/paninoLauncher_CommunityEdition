import SwiftUI

extension LaunchDashboard {
    var corePreflightItem: LaunchPreflightItem {
        if viewModel.coreState.isReady {
            return LaunchPreflightItem(
                id: "core",
                title: localizedString(theme.language, english: "Core service", chinese: "Core 服务", italian: "Servizio Core", french: "Service Core", spanish: "Servicio Core"),
                detail: viewModel.coreState.detail,
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        return LaunchPreflightItem(
            id: "core",
            title: localizedString(theme.language, english: "Core service", chinese: "Core 服务", italian: "Servizio Core", french: "Service Core", spanish: "Servicio Core"),
            detail: viewModel.coreState.detail,
            state: .needsFix,
            actionTitle: localizedString(theme.language, english: "Start", chinese: "启动", italian: "Avvia", french: "Démarrer", spanish: "Iniciar")
        ) {
            Task { await viewModel.startCoreIfNeeded() }
        }
    }

    var javaPreflightItem: LaunchPreflightItem {
        if let resolution = javaResolution(for: selectedInstance) {
            if resolution.isReady {
                return LaunchPreflightItem(
                    id: "java",
                    title: AppText.java.localized(theme.language),
                    detail: resolution.conciseStatus,
                    state: .ready,
                    actionTitle: nil,
                    action: nil
                )
            }
            if resolution.isDownloadable {
                return LaunchPreflightItem(
                    id: "java",
                    title: AppText.java.localized(theme.language),
                    detail: resolution.conciseStatus,
                    state: .needsFix,
                    actionTitle: localizedString(theme.language, english: "Download Java \(resolution.requiredMajorVersion)", chinese: "下载 Java \(resolution.requiredMajorVersion)", italian: "Scarica Java \(resolution.requiredMajorVersion)", french: "Télécharger Java \(resolution.requiredMajorVersion)", spanish: "Descargar Java \(resolution.requiredMajorVersion)")
                ) {
                    viewModel.installManagedJavaRuntime(featureVersion: resolution.requiredMajorVersion)
                }
            }
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: resolution.conciseStatus,
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"),
                action: openSettings
            )
        }

        guard let javaStatus = viewModel.javaStatus else {
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: viewModel.javaRuntimeStatus,
                state: .optional,
                actionTitle: localizedString(theme.language, english: "Resolve", chinese: "解析", italian: "Risolvi", french: "Résoudre", spanish: "Resolver"),
                action: refreshSelectedJavaRuntime
            )
        }
        if !javaStatus.isAvailable {
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: javaStatus.displayText,
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Controlla", french: "Vérifier", spanish: "Comprobar"),
                action: viewModel.checkJavaRuntime
            )
        }
        if let requiredJavaMajor, let current = javaMajorVersion(from: javaStatus.versionSummary), current < requiredJavaMajor {
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: localizedString(theme.language, english: "Requires Java \(requiredJavaMajor), current runtime looks like Java \(current).", chinese: "需要 Java \(requiredJavaMajor)，当前运行时看起来是 Java \(current)。", italian: "Richiede Java \(requiredJavaMajor), runtime attuale Java \(current).", french: "Nécessite Java \(requiredJavaMajor), runtime actuel Java \(current).", spanish: "Requiere Java \(requiredJavaMajor), runtime actual Java \(current)."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Change Java", chinese: "更换 Java", italian: "Cambia Java", french: "Changer Java", spanish: "Cambiar Java"),
                action: openSettings
            )
        }
        return LaunchPreflightItem(
            id: "java",
            title: AppText.java.localized(theme.language),
            detail: requiredJavaMajor.map { localizedString(theme.language, english: "Java runtime is available. Required: Java \($0).", chinese: "Java 可用。需要：Java \($0)。", italian: "Runtime Java disponibile. Richiesto: Java \($0).", french: "Runtime Java disponible. Requis : Java \($0).", spanish: "Runtime Java disponible. Requerido: Java \($0).") } ?? javaStatus.displayText,
            state: .ready,
            actionTitle: nil,
            action: nil
        )
    }


    var versionPreflightItem: LaunchPreflightItem {
        switch versionInstallState {
        case .installed:
            return LaunchPreflightItem(
                id: "version",
                title: localizedString(theme.language, english: "Minecraft files", chinese: "Minecraft 文件", italian: "File Minecraft", french: "Fichiers Minecraft", spanish: "Archivos Minecraft"),
                detail: localizedString(theme.language, english: "\(selectedInstance.minecraftVersion) is installed and verified.", chinese: "\(selectedInstance.minecraftVersion) 已安装并通过校验。", italian: "\(selectedInstance.minecraftVersion) installato e verificato.", french: "\(selectedInstance.minecraftVersion) installé et vérifié.", spanish: "\(selectedInstance.minecraftVersion) instalado y verificado."),
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        case .available:
            return LaunchPreflightItem(
                id: "version",
                title: localizedString(theme.language, english: "Minecraft files", chinese: "Minecraft 文件", italian: "File Minecraft", french: "Fichiers Minecraft", spanish: "Archivos Minecraft"),
                detail: localizedString(theme.language, english: "\(selectedInstance.minecraftVersion) will be installed before launch.", chinese: "\(selectedInstance.minecraftVersion) 会在启动前安装。", italian: "\(selectedInstance.minecraftVersion) verrà installato prima dell'avvio.", french: "\(selectedInstance.minecraftVersion) sera installé avant le lancement.", spanish: "\(selectedInstance.minecraftVersion) se instalará antes de iniciar."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"),
                action: { installSelectedVersion() }
            )
        case .unknown:
            return LaunchPreflightItem(
                id: "version",
                title: localizedString(theme.language, english: "Minecraft files", chinese: "Minecraft 文件", italian: "File Minecraft", french: "Fichiers Minecraft", spanish: "Archivos Minecraft"),
                detail: localizedString(theme.language, english: "Version status is still loading from Core.", chinese: "版本状态仍在从 Core 加载。", italian: "Stato versione in caricamento da Core.", french: "État de version encore chargé depuis Core.", spanish: "Estado de versión cargando desde Core."),
                state: .optional,
                actionTitle: nil,
                action: nil
            )
        }
    }

    var accountPreflightItem: LaunchPreflightItem {
        if let account = viewModel.accountState.account, !account.isExpired {
            return LaunchPreflightItem(
                id: "account",
                title: AppText.account.localized(theme.language),
                detail: localizedString(theme.language, english: "Signed in as \(account.name).", chinese: "已登录为 \(account.name)。", italian: "Accesso come \(account.name).", french: "Connecté en tant que \(account.name).", spanish: "Sesión iniciada como \(account.name)."),
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        if let profile = accountStore.defaultAccount, profile.loginStatus == .expired {
            return LaunchPreflightItem(
                id: "account",
                title: AppText.account.localized(theme.language),
                detail: localizedString(theme.language, english: "\(profile.name)'s Microsoft session needs refresh.", chinese: "\(profile.name) 的 Microsoft 会话需要刷新。", italian: "La sessione Microsoft di \(profile.name) va aggiornata.", french: "La session Microsoft de \(profile.name) doit être actualisée.", spanish: "La sesión Microsoft de \(profile.name) debe actualizarse."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Refresh", chinese: "刷新", italian: "Aggiorna", french: "Actualiser", spanish: "Actualizar")
            ) {
                Task { await viewModel.restoreAccountIfPossible(accountID: profile.id) }
            }
        }
        if let profile = accountStore.defaultAccount, profile.loginStatus == .signedIn {
            return LaunchPreflightItem(
                id: "account",
                title: AppText.account.localized(theme.language),
                detail: localizedString(theme.language, english: "\(profile.name) is ready for launch.", chinese: "\(profile.name) 可用于启动。", italian: "\(profile.name) pronto per l'avvio.", french: "\(profile.name) prêt pour le lancement.", spanish: "\(profile.name) listo para iniciar."),
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        return LaunchPreflightItem(
            id: "account",
            title: AppText.account.localized(theme.language),
            detail: localizedString(theme.language, english: "No online account is selected; launch will use offline fallback where allowed.", chinese: "未选择在线账号；允许时会使用离线回退启动。", italian: "Nessun account online selezionato; verrà usato il fallback offline se consentito.", french: "Aucun compte en ligne sélectionné ; le mode hors ligne sera utilisé si possible.", spanish: "No hay cuenta online seleccionada; se usará modo offline si se permite."),
            state: .optional,
            actionTitle: localizedString(theme.language, english: "Account", chinese: "账号", italian: "Account", french: "Compte", spanish: "Cuenta"),
            action: openAccount
        )
    }

    var diskPreflightItem: LaunchPreflightItem {
        if isGameDirectoryWritable {
            return LaunchPreflightItem(
                id: "disk",
                title: localizedString(theme.language, english: "Game directory", chinese: "游戏目录", italian: "Cartella gioco", french: "Dossier du jeu", spanish: "Directorio del juego"),
                detail: selectedInstance.gameDirectory,
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        return LaunchPreflightItem(
            id: "disk",
            title: localizedString(theme.language, english: "Game directory", chinese: "游戏目录", italian: "Cartella gioco", french: "Dossier du jeu", spanish: "Directorio del juego"),
            detail: localizedString(theme.language, english: "The selected directory is not writable or is missing.", chinese: "所选目录不可写或不存在。", italian: "La cartella scelta non è scrivibile o manca.", french: "Le dossier choisi n'est pas accessible en écriture ou manque.", spanish: "El directorio elegido no es escribible o no existe."),
            state: .needsFix,
            actionTitle: localizedString(theme.language, english: "Edit", chinese: "编辑", italian: "Modifica", french: "Modifier", spanish: "Editar"),
            action: openInstances
        )
    }

    var resourcePreflightItem: LaunchPreflightItem {
        if conflictCount > 0 || missingDependencyCount > 0 || archivedDeprecatedCount > 0 {
            return LaunchPreflightItem(
                id: "resources",
                title: localizedString(theme.language, english: "Resources", chinese: "资源内容", italian: "Risorse", french: "Ressources", spanish: "Recursos"),
                detail: localizedString(theme.language, english: "\(conflictCount) conflicts, \(missingDependencyCount) dependency warnings, \(archivedDeprecatedCount) archived/deprecated hints.", chinese: "\(conflictCount) 个冲突，\(missingDependencyCount) 个依赖风险，\(archivedDeprecatedCount) 个归档/弃用提示。", italian: "\(conflictCount) conflitti, \(missingDependencyCount) avvisi dipendenze, \(archivedDeprecatedCount) indizi archiviati/deprecati.", french: "\(conflictCount) conflits, \(missingDependencyCount) alertes de dépendances, \(archivedDeprecatedCount) indices archivés/obsolètes.", spanish: "\(conflictCount) conflictos, \(missingDependencyCount) avisos de dependencias, \(archivedDeprecatedCount) indicios archivados/obsoletos."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Review", chinese: "查看", italian: "Controlla", french: "Vérifier", spanish: "Revisar"),
                action: openResources
            )
        }
        let count = versionStore.managedAssets.count
        return LaunchPreflightItem(
            id: "resources",
            title: localizedString(theme.language, english: "Resources", chinese: "资源内容", italian: "Risorse", french: "Ressources", spanish: "Recursos"),
            detail: count == 0
                ? localizedString(theme.language, english: "No managed resources scanned for the selected content type.", chinese: "当前内容类型下未扫描到资源。", italian: "Nessuna risorsa gestita trovata per il tipo scelto.", french: "Aucune ressource gérée trouvée pour le type choisi.", spanish: "No se encontraron recursos gestionados para el tipo actual.")
                : localizedString(theme.language, english: "\(count) managed files scanned.", chinese: "已扫描 \(count) 个托管文件。", italian: "\(count) file gestiti analizzati.", french: "\(count) fichiers gérés analysés.", spanish: "\(count) archivos gestionados escaneados."),
            state: count == 0 ? .optional : .ready,
            actionTitle: count == 0 ? localizedString(theme.language, english: "Discover", chinese: "发现", italian: "Scopri", french: "Découvrir", spanish: "Descubrir") : nil,
            action: count == 0 ? openDiscover : nil
        )
    }

    enum VersionInstallState {
        case installed
        case available
        case unknown
    }

    var versionInstallState: VersionInstallState {
        if let version = versionStore.versions.first(where: { $0.id == selectedInstance.minecraftVersion }) {
            return version.isInstalled ? .installed : .available
        }
        switch selectedInstance.status {
        case .ready, .running:
            return .installed
        case .notInstalled:
            return .available
        case .installing:
            return .unknown
        case .failed:
            return .available
        }
    }

    var versionInfo: MinecraftVersionInfo? {
        versionStore.versions.first { $0.id == selectedInstance.minecraftVersion }
    }

    var requiredJavaMajor: Int? {
        guard let text = versionInfo?.javaRequirement else { return nil }
        return javaMajorVersion(from: text)
    }

    func javaResolution(for instance: GameInstance) -> CoreJavaRuntimeResolveResponse? {
        guard let resolution = viewModel.javaRuntimeResolution,
              resolution.minecraftVersion == instance.minecraftVersion else {
            return nil
        }
        return resolution
    }

    var isGameDirectoryWritable: Bool {
        let path = selectedInstance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return false }
        let directoryPath = path
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directoryPath) {
            return fileManager.isWritableFile(atPath: directoryPath)
        }
        let parent = URL(fileURLWithPath: directoryPath).deletingLastPathComponent().path
        return fileManager.isWritableFile(atPath: parent)
    }

    var conflictCount: Int {
        versionStore.managedAssets.filter { $0.conflictMessage != nil }.count
    }

    var missingDependencyCount: Int {
        versionStore.managedAssets.filter { asset in
            let text = (asset.conflictMessage ?? "") + " " + (asset.metadata.summary ?? "")
            let lowercased = text.lowercased()
            return lowercased.contains("missing") || lowercased.contains("dependency") || lowercased.contains("依赖")
        }.count
    }

    var archivedDeprecatedCount: Int {
        versionStore.managedAssets.filter { asset in
            let text = [asset.name, asset.metadata.displayName, asset.metadata.summary, asset.source]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
            return text.contains("archived")
                || text.contains("deprecated")
                || text.contains("withheld")
                || text.contains("弃用")
                || text.contains("归档")
        }.count
    }

    var updateCandidateCount: Int {
        versionStore.managedAssets.filter { $0.projectURL != nil || ($0.source?.isEmpty == false) }.count
    }

    var recentChangeCount: Int {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return versionStore.managedAssets.filter { ($0.modifiedAt ?? .distantPast) >= cutoff }.count
    }

    var sourceSummary: String {
        let sources = Set(versionStore.managedAssets.compactMap { $0.source?.isEmpty == false ? $0.source : nil })
        if sources.isEmpty {
            return localizedString(theme.language, english: "Local files", chinese: "本地文件", italian: "File locali", french: "Fichiers locaux", spanish: "Archivos locales")
        }
        return sources.sorted().prefix(3).joined(separator: ", ")
    }

    var resourceSummary: String {
        let count = versionStore.managedAssets.count
        return localizedString(theme.language, english: "\(count) \(versionStore.selectedAssetKind.title)", chinese: "\(count) 个 \(versionStore.selectedAssetKind.title)", italian: "\(count) \(versionStore.selectedAssetKind.title)", french: "\(count) \(versionStore.selectedAssetKind.title)", spanish: "\(count) \(versionStore.selectedAssetKind.title)")
    }

}
