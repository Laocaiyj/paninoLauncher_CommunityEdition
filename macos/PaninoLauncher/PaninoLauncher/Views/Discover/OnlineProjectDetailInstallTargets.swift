import SwiftUI

struct InstallTargetSection: View {
    let release: OnlineRelease
    let currentMinecraftVersion: String?
    let targetResolution: CoreContentResolveTargetsResponse?
    @Binding var selectedTargetID: String?
    let targetFailure: String?
    let install: (CoreContentTargetCandidate?) -> Void
    let openTasks: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAllTargets = false

    private var selectedFile: OnlineFile? {
        release.files.first(where: \.isPrimary) ?? release.files.first
    }

    private var recommendedTarget: CoreContentTargetCandidate? {
        guard let target = targetResolution?.recommended, isVersionMatched(target) else { return nil }
        return target
    }

    private var versionMatchedTargets: [CoreContentTargetCandidate] {
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

    private var selectedTarget: CoreContentTargetCandidate? {
        guard let selectedTargetID else { return nil }
        return versionMatchedTargets.first { $0.id == selectedTargetID }
    }

    private var activeTarget: CoreContentTargetCandidate? {
        selectedTarget ?? recommendedTarget
    }

    private var visibleTargets: [CoreContentTargetCandidate] {
        showAllTargets ? versionMatchedTargets : Array(versionMatchedTargets.prefix(5))
    }

    private var hiddenTargetCount: Int {
        max(versionMatchedTargets.count - visibleTargets.count, 0)
    }

    private var hasVersionMatchedTarget: Bool {
        !versionMatchedTargets.isEmpty
    }

    private var canInstall: Bool {
        selectedFile?.downloadURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizedString(theme.language, english: "Install Target", chinese: "安装目标", italian: "Destinazione installazione", french: "Cible d'installation", spanish: "Destino de instalación"))
                    .font(.headline)
                Spacer()
                if hasVersionMatchedTarget {
                    CountText(value: versionMatchedTargets.count, style: .download)
                }
            }

            if let targetFailure {
                Label(localizedOnlineError(targetFailure, language: theme.language), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            } else if targetResolution != nil {
                if versionMatchedTargets.isEmpty {
                    Label(noMatchingInstanceMessage, systemImage: "tray")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleTargets) { target in
                            Button {
                                selectedTargetID = target.id
                            } label: {
                                TargetCandidateRow(
                                    target: target,
                                    selected: target.id == activeTarget?.id,
                                    recommended: target.id == recommendedTarget?.id
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if versionMatchedTargets.count > 5 {
                            Button {
                                withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                                    showAllTargets.toggle()
                                }
                            } label: {
                                Label(showMoreTargetsTitle, systemImage: showAllTargets ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.semanticSelectionColor)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localizedString(theme.language, english: "Matching local instances...", chinese: "正在匹配本地实例...", italian: "Ricerca istanze locali...", french: "Recherche des instances locales...", spanish: "Buscando instancias locales..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlassButton(systemImage: primaryButtonIcon, title: primaryButtonTitle, prominent: true) {
                        install(activeTarget)
                    }
                        .disabled(!canInstall)
                    GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas"), action: openTasks)
                }

                if !canInstall {
                    Text(localizedString(theme.language, english: "Missing downloadable file for the selected release.", chinese: "所选版本缺少可下载文件。", italian: "File scaricabile mancante.", french: "Fichier téléchargeable manquant.", spanish: "Falta archivo descargable."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var showMoreTargetsTitle: String {
        if showAllTargets {
            return localizedString(theme.language, english: "Show Fewer Targets", chinese: "收起匹配实例", italian: "Mostra meno destinazioni", french: "Afficher moins de cibles", spanish: "Mostrar menos destinos")
        }
        return localizedString(theme.language, english: "\(hiddenTargetCount) more matching targets", chinese: "还有 \(hiddenTargetCount) 个匹配实例", italian: "Altre \(hiddenTargetCount) destinazioni", french: "\(hiddenTargetCount) autres cibles", spanish: "\(hiddenTargetCount) destinos más")
    }

    private var primaryButtonTitle: String {
        if activeTarget != nil {
            return localizedString(theme.language, english: "Install to Selected Instance", chinese: "安装到所选实例", italian: "Installa nell'istanza selezionata", french: "Installer dans l'instance choisie", spanish: "Instalar en instancia seleccionada")
        }
        return localizedString(theme.language, english: "Choose Folder and Install", chinese: "选择文件夹并安装", italian: "Scegli cartella e installa", french: "Choisir dossier et installer", spanish: "Elegir carpeta e instalar")
    }

    private var primaryButtonIcon: String {
        activeTarget == nil ? "folder.badge.gearshape" : "arrow.down.circle"
    }

    private var noMatchingInstanceMessage: String {
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

private struct TargetCandidateRow: View {
    let target: CoreContentTargetCandidate
    let selected: Bool
    let recommended: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(target.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                PlainStatusText(title: statusTitle, style: statusStyle)
            }
            Text([
                "Minecraft \(target.minecraftVersion)",
                target.loader.map { loaderTitle($0) }
            ].compactMap { $0 }.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            if let reasonSummary {
                Text(reasonSummary)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(selected ? 0.46 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? theme.semanticSelectionColor.opacity(0.7) : Color(nsColor: .separatorColor).opacity(0.28), lineWidth: selected ? 1.5 : 1)
        }
        .help(target.gameDir)
    }

    private var statusTitle: String {
        if target.blockedReasons.isEmpty {
            return selected
                ? localizedString(theme.language, english: "Selected", chinese: "已选择", italian: "Selezionata", french: "Sélectionnée", spanish: "Seleccionada")
                : recommended
                ? localizedString(theme.language, english: "Recommended", chinese: "推荐", italian: "Consigliata", french: "Recommandée", spanish: "Recomendada")
                : localizedString(theme.language, english: "Matched", chinese: "匹配", italian: "Compatibile", french: "Compatible", spanish: "Compatible")
        }
        return localizedString(theme.language, english: "Review", chinese: "需确认", italian: "Verifica", french: "À vérifier", spanish: "Revisar")
    }

    private var statusStyle: StatusBadge.Style {
        target.blockedReasons.isEmpty ? .success : .warning
    }

    private var reasonSummary: String? {
        let reasons = target.blockedReasons.filter { !$0.localizedCaseInsensitiveContains("minecraft_version_mismatch") }
        guard !reasons.isEmpty else { return nil }
        return reasons.joined(separator: ", ")
    }

    private func loaderTitle(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "fabric": return "Fabric"
        case "quilt": return "Quilt"
        case "forge": return "Forge"
        case "neoforge": return "NeoForge"
        default: return rawValue
        }
    }
}

struct ReleaseFileDetailsSection: View {
    let release: OnlineRelease

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isExpanded = true

    private var primaryFile: OnlineFile? {
        release.files.first(where: \.isPrimary) ?? release.files.first
    }

    var body: some View {
        FullWidthDisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 7) {
                if let primaryFile {
                    metadataRow("File", primaryFile.fileName)
                    metadataRow("Size", formattedBytes(primaryFile.sizeBytes))
                    ForEach(primaryFile.hashes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        metadataRow(key.uppercased(), value)
                    }
                }
                metadataRow("Release", release.releaseType.rawValue.capitalized)
                metadataRow("Game", release.gameVersions.prefix(6).joined(separator: ", "))
                metadataRow("Loader", release.loaders.map(\.displayTitle).joined(separator: ", "))

                if !release.dependencies.isEmpty {
                    Text(localizedString(theme.language, english: "Dependencies", chinese: "依赖", italian: "Dipendenze", french: "Dépendances", spanish: "Dependencias"))
                        .font(.caption.weight(.semibold))
                    ForEach(release.dependencies.prefix(8)) { dependency in
                        Text("\(dependency.relation.rawValue): \(dependency.projectID ?? dependency.versionID ?? dependency.id)")
                            .font(.caption)
                            .foregroundStyle(dependency.relation == .incompatible ? .orange : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let changelog = release.changelog, !changelog.isEmpty {
                    Text(localizedString(theme.language, english: "Changelog", chinese: "更新日志", italian: "Registro modifiche", french: "Journal des modifications", spanish: "Cambios"))
                        .font(.caption.weight(.semibold))
                    SafeDescriptionText(text: changelog, lineLimit: 8)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(localizedString(theme.language, english: "File Details", chinese: "文件详情", italian: "Dettagli file", french: "Détails du fichier", spanish: "Detalles del archivo"))
                    .font(.headline)
                Spacer()
                if let primaryFile {
                    Text(formattedBytes(primaryFile.sizeBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

struct OnlineUnsupportedInstallFlowView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
    }
}
