extension InstallTargetSection {
    var selectedFile: OnlineFile? {
        release.files.first(where: \.isPrimary) ?? release.files.first
    }

    var recommendedTarget: CoreContentTargetCandidate? {
        guard let target = targetResolution?.recommended, isVersionMatched(target) else { return nil }
        return target
    }

    var versionMatchedTargets: [CoreContentTargetCandidate] {
        guard let targetResolution else { return [] }
        var seen = Set<String>()
        var targets: [CoreContentTargetCandidate] = []
        if let recommendedTarget, seen.insert(recommendedTarget.id).inserted {
            targets.append(recommendedTarget)
        }
        for candidate in targetResolution.candidates where isVersionMatched(candidate) {
            if seen.insert(candidate.id).inserted {
                targets.append(candidate)
            }
        }
        return targets
    }

    var selectedTarget: CoreContentTargetCandidate? {
        guard let selectedTargetID else { return nil }
        return versionMatchedTargets.first { $0.id == selectedTargetID }
    }

    var activeTarget: CoreContentTargetCandidate? {
        selectedTarget ?? recommendedTarget
    }

    var visibleTargets: [CoreContentTargetCandidate] {
        showAllTargets ? versionMatchedTargets : Array(versionMatchedTargets.prefix(5))
    }

    var hiddenTargetCount: Int {
        max(versionMatchedTargets.count - visibleTargets.count, 0)
    }

    var hasVersionMatchedTarget: Bool {
        !versionMatchedTargets.isEmpty
    }

    var canInstall: Bool {
        selectedFile?.downloadURL != nil
    }

    var showMoreTargetsTitle: String {
        if showAllTargets {
            return localizedString(theme.language, english: "Show Fewer Targets", chinese: "收起匹配实例", italian: "Mostra meno destinazioni", french: "Afficher moins de cibles", spanish: "Mostrar menos destinos")
        }
        return localizedString(theme.language, english: "\(hiddenTargetCount) more matching targets", chinese: "还有 \(hiddenTargetCount) 个匹配实例", italian: "Altre \(hiddenTargetCount) destinazioni", french: "\(hiddenTargetCount) autres cibles", spanish: "\(hiddenTargetCount) destinos más")
    }

    var primaryButtonTitle: String {
        if activeTarget != nil {
            return localizedString(theme.language, english: "Install to Selected Instance", chinese: "安装到所选实例", italian: "Installa nell'istanza selezionata", french: "Installer dans l'instance choisie", spanish: "Instalar en instancia seleccionada")
        }
        return localizedString(theme.language, english: "Choose Folder and Install", chinese: "选择文件夹并安装", italian: "Scegli cartella e installa", french: "Choisir dossier et installer", spanish: "Elegir carpeta e instalar")
    }

    var primaryButtonIcon: String {
        activeTarget == nil ? "folder.badge.gearshape" : "arrow.down.circle"
    }

    var noMatchingInstanceMessage: String {
        let version = currentMinecraftVersion ?? release.gameVersions.first ?? "-"
        return localizedString(
            theme.language,
            english: "No local instance matches Minecraft \(version).",
            chinese: "没有匹配 Minecraft \(version) 的本地实例。",
            italian: "Nessuna istanza locale per Minecraft \(version).",
            french: "Aucune instance locale pour Minecraft \(version).",
            spanish: "No hay instancia local para Minecraft \(version)."
        )
    }

    private func isVersionMatched(_ target: CoreContentTargetCandidate) -> Bool {
        let hasVersionMismatch = target.blockedReasons.contains { reason in
            reason.localizedCaseInsensitiveContains("minecraft_version_mismatch")
        }
        guard !hasVersionMismatch else { return false }
        return release.gameVersions.isEmpty || release.gameVersions.contains(target.minecraftVersion)
    }
}
