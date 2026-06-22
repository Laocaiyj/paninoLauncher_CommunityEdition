import SwiftUI

extension LaunchDashboard {
    var corePreflightItem: LaunchPreflightItem {
        if viewModel.coreState.isReady {
            return LaunchPreflightItem(
                id: "core",
                title: localizedString(theme.language, english: "Core service", chinese: "Core 服务", italian: "Servizio Core", french: "Service Core", spanish: "Servicio Core"),
                detail: viewModel.coreState.detail,
                state: .ready
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

    var versionPreflightItem: LaunchPreflightItem {
        switch versionInstallState {
        case .installed:
            return LaunchPreflightItem(
                id: "version",
                title: localizedString(theme.language, english: "Minecraft files", chinese: "Minecraft 文件", italian: "File Minecraft", french: "Fichiers Minecraft", spanish: "Archivos Minecraft"),
                detail: localizedString(theme.language, english: "\(selectedInstance.minecraftVersion) is installed and verified.", chinese: "\(selectedInstance.minecraftVersion) 已安装并通过校验。", italian: "\(selectedInstance.minecraftVersion) installato e verificato.", french: "\(selectedInstance.minecraftVersion) installé et vérifié.", spanish: "\(selectedInstance.minecraftVersion) instalado y verificado."),
                state: .ready
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
                state: .optional
            )
        }
    }

    var diskPreflightItem: LaunchPreflightItem {
        if isGameDirectoryWritable {
            return LaunchPreflightItem(
                id: "disk",
                title: localizedString(theme.language, english: "Game directory", chinese: "游戏目录", italian: "Cartella gioco", french: "Dossier du jeu", spanish: "Directorio del juego"),
                detail: selectedInstance.gameDirectory,
                state: .ready
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

}
