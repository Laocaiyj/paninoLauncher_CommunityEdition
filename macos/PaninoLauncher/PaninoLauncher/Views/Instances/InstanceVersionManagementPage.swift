import SwiftUI

struct InstanceVersionManagementPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let openResources: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var theme: ThemeSettings
    @State private var focusedVersionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let focusedVersion {
                InstanceVersionConfigurationPage(
                    viewModel: viewModel,
                    instance: $instance,
                    version: focusedVersion,
                    openResources: openResources,
                    openDiscover: openDiscover,
                    onBack: { focusedVersionID = nil }
                )
            } else {
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            PanelHeader(
                                title: localizedString(theme.language, english: "Installed Versions", chinese: "已安装版本", italian: "Versioni installate", french: "Versions installées", spanish: "Versiones instaladas"),
                                systemImage: "externaldrive.badge.checkmark"
                            )
                            Spacer()
                            GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                                versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
                            }
                            GlassButton(
                                systemImage: "arrow.down.app",
                                title: localizedString(theme.language, english: "Download Versions", chinese: "下载版本", italian: "Scarica versioni", french: "Télécharger versions", spanish: "Descargar versiones"),
                                prominent: true,
                                action: openDiscover
                            )
                        }

                        Text(localizedString(
                            theme.language,
                            english: "This list only manages versions already installed on disk. New Minecraft version downloads live in Discover.",
                            chinese: "这里仅管理磁盘内已安装的版本。新 Minecraft 版本下载请前往“发现”。",
                            italian: "Qui gestisci solo versioni già installate su disco. I download di nuove versioni sono in Scopri.",
                            french: "Cette liste gère uniquement les versions déjà installées. Les nouvelles versions se téléchargent dans Découvrir.",
                            spanish: "Aquí solo se gestionan versiones ya instaladas. Las nuevas versiones se descargan en Descubrir."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if installedVersions.isEmpty {
                            ContentUnavailableView(
                                localizedString(theme.language, english: "No Installed Minecraft Versions", chinese: "没有已安装的 Minecraft 版本", italian: "Nessuna versione Minecraft installata", french: "Aucune version Minecraft installée", spanish: "Sin versiones de Minecraft instaladas"),
                                systemImage: "externaldrive.badge.questionmark",
                                description: Text(localizedString(theme.language, english: "Download a version from Discover, then return here to configure it.", chinese: "请先在“发现”中下载版本，然后回到这里配置。", italian: "Scarica una versione da Scopri, poi torna qui per configurarla.", french: "Téléchargez une version depuis Découvrir, puis revenez la configurer.", spanish: "Descarga una versión desde Descubrir y vuelve para configurarla."))
                            )
                            .frame(minHeight: 180)
                        } else {
                            InstanceVersionCardSection(
                                title: localizedString(theme.language, english: "Release", chinese: "正式版", italian: "Stabili", french: "Stables", spanish: "Estables"),
                                versions: installedReleaseVersions,
                                selectedID: instance.minecraftVersion,
                                select: openVersionConfiguration
                            )

                            InstanceVersionCardSection(
                                title: localizedString(theme.language, english: "Snapshot", chinese: "快照版", italian: "Snapshot", french: "Snapshots", spanish: "Snapshots"),
                                versions: installedSnapshotVersions,
                                selectedID: instance.minecraftVersion,
                                select: openVersionConfiguration
                            )

                            InstanceVersionCardSection(
                                title: localizedString(theme.language, english: "Historical", chinese: "历史版本", italian: "Storiche", french: "Historiques", spanish: "Históricas"),
                                versions: installedHistoricalVersions,
                                selectedID: instance.minecraftVersion,
                                select: openVersionConfiguration
                            )
                        }
                    }
                }
            }
        }
        .task(id: instance.minecraftVersion) {
            versionStore.selectedVersionID = instance.minecraftVersion
            versionStore.refreshAssets(for: instance)
            if let selectedVersion {
                versionStore.loadDetails(for: selectedVersion, instances: instanceStore.instances, settings: launcherSettings)
            }
        }
    }

    private var focusedVersion: MinecraftVersionInfo? {
        guard let focusedVersionID else { return nil }
        return versionStore.versions.first { $0.id == focusedVersionID }
    }

    private var selectedVersion: MinecraftVersionInfo? {
        versionStore.versions.first { $0.id == instance.minecraftVersion }
    }

    private var installedVersions: [MinecraftVersionInfo] {
        uniqueVersions(versionStore.versions.filter { $0.isInstalled || $0.isArchived || $0.isUsedByInstance })
            .sorted {
                if $0.isUsedByInstance != $1.isUsedByInstance { return $0.isUsedByInstance && !$1.isUsedByInstance }
                if $0.isInstalled != $1.isInstalled { return $0.isInstalled && !$1.isInstalled }
                if $0.isArchived != $1.isArchived { return !$0.isArchived && $1.isArchived }
                if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
                return $0.id.localizedStandardCompare($1.id) == .orderedDescending
            }
    }

    private var installedReleaseVersions: [MinecraftVersionInfo] {
        installedVersions.filter { $0.kind == .release }
    }

    private var installedSnapshotVersions: [MinecraftVersionInfo] {
        installedVersions.filter { $0.kind == .snapshot }
    }

    private var installedHistoricalVersions: [MinecraftVersionInfo] {
        installedVersions.filter { $0.kind == .oldBeta || $0.kind == .oldAlpha }
    }

    private func openVersionConfiguration(_ version: MinecraftVersionInfo) {
        focusedVersionID = version.id
        versionStore.selectedVersionID = version.id
        versionStore.loadDetails(for: version, instances: instanceStore.instances, settings: launcherSettings)
        versionStore.refreshAssets(for: instance)
    }
}

private struct InstanceVersionCardSection: View {
    let title: String
    let versions: [MinecraftVersionInfo]
    let selectedID: String
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        if !versions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    CountText(value: versions.count)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 176), spacing: 10)], spacing: 10) {
                    ForEach(versions) { version in
                        InstanceVersionManagementCard(
                            version: version,
                            isSelected: version.id == selectedID
                        ) {
                            select(version)
                        }
                    }
                }
            }
        }
    }
}

private struct InstanceVersionManagementCard: View {
    let version: MinecraftVersionInfo
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(version.id)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? theme.semanticSelectionColor : .secondary)
                }

                Text("\(version.kind.title(language: theme.language)) · \(version.javaRequirement)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if version.isUsedByInstance {
                        StatusBadge(title: localizedString(theme.language, english: "Used by Config", chinese: "配置使用中", italian: "Usata", french: "Utilisée", spanish: "En uso"), style: .success)
                    } else if version.isInstalled {
                        StatusBadge(title: localizedString(theme.language, english: "Installed", chinese: "已安装", italian: "Installata", french: "Installée", spanish: "Instalada"), style: .success)
                    } else if version.isArchived {
                        StatusBadge(title: localizedString(theme.language, english: "Archived", chinese: "已归档", italian: "Archiviata", french: "Archivée", spanish: "Archivada"), style: .neutral)
                    } else {
                        StatusBadge(title: localizedString(theme.language, english: "Available", chinese: "可安装", italian: "Disponibile", french: "Disponible", spanish: "Disponible"), style: .download)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(
                isSelected ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.34),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.85) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct InstanceVersionConfigurationPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let version: MinecraftVersionInfo?
    let openResources: () -> Void
    let openDiscover: () -> Void
    let onBack: () -> Void

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings
    @State private var confirmApplyVersion = false
    @State private var pendingStorageAction: VersionStorageConfirmation?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        GlassButton(
                            systemImage: "chevron.left",
                            title: localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Atrás"),
                            action: onBack
                        )
                        PanelHeader(
                            title: localizedString(theme.language, english: "Version Runtime", chinese: "版本运行设置", italian: "Runtime versione", french: "Runtime version", spanish: "Runtime de versión"),
                            systemImage: "slider.horizontal.3"
                        )
                        StatusBadge(title: versionStateTitle, style: versionBadgeStyle)
                        Spacer()
                        if canApplyVersion {
                            GlassButton(
                                systemImage: "checkmark.circle",
                                title: localizedString(theme.language, english: "Apply to Configuration", chinese: "应用到配置", italian: "Applica", french: "Appliquer", spanish: "Aplicar"),
                                prominent: true
                            ) {
                                confirmApplyVersion = true
                            }
                        }
                        GlassButton(systemImage: "checkmark.seal", title: localizedString(theme.language, english: "Repair Files", chinese: "修复文件", italian: "Ripara file", french: "Réparer fichiers", spanish: "Reparar archivos"), prominent: true) {
                            repairFocusedVersion()
                        }
                        .disabled(version?.isInstalled != true)
                        GlassButton(
                            systemImage: "arrow.down.app",
                            title: localizedString(theme.language, english: "Get Versions", chinese: "获取版本", italian: "Ottieni versioni", french: "Obtenir versions", spanish: "Obtener versiones"),
                            action: openDiscover
                        )
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                        versionMetric(AppText.java.localized(theme.language), version?.javaRequirement ?? "--", "cup.and.saucer")
                        versionMetric(AppText.loader.localized(theme.language), instance.loader?.title ?? "Vanilla", "puzzlepiece.extension")
                        versionMetric(AppText.download.localized(theme.language), version?.downloadState.localizedVersionState(theme.language) ?? "--", "arrow.down.circle")
                        versionMetric(AppText.verify.localized(theme.language), version?.verificationState.localizedVersionState(theme.language) ?? "--", "checkmark.seal")
                    }

                    versionStorageControls

                    SettingsRow(
                        title: localizedString(theme.language, english: "Use Global Runtime", chinese: "使用全局运行环境", italian: "Usa runtime globale", french: "Utiliser runtime global", spanish: "Usar runtime global"),
                        systemImage: "globe"
                    ) {
                        Toggle("", isOn: usesGlobalRuntime)
                            .toggleStyle(.switch)
                    }

                    SettingsRow(title: AppText.loader.localized(theme.language), systemImage: "puzzlepiece.extension") {
                        Picker(AppText.loader.localized(theme.language), selection: $instance.loader) {
                            Text("Vanilla").tag(nil as LoaderKind?)
                            ForEach(compatibleLoaders) { loader in
                                Text(loader.title).tag(Optional(loader))
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 520)
                    }

                    SettingsRow(title: AppText.java.localized(theme.language), systemImage: "cup.and.saucer") {
                        VStack(alignment: .leading, spacing: 8) {
                            JavaRuntimePolicySelector(
                                javaPath: $instance.javaPath,
                                managedRuntimes: viewModel.managedJavaRuntimes,
                                localRuntimes: viewModel.discoveredJavaRuntimes
                            )
                            .disabled(usesGlobalRuntime.wrappedValue)

                            HStack(spacing: 8) {
                                GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan", chinese: "扫描", italian: "Scansiona", french: "Scanner", spanish: "Escanear")) {
                                    viewModel.scanJavaRuntimes()
                                }
                                Text(viewModel.javaScanStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    SettingsRow(title: localizedString(theme.language, english: "Performance", chinese: "性能配置", italian: "Prestazioni", french: "Performance", spanish: "Rendimiento"), systemImage: "speedometer") {
                        JvmTuningControl(
                            memoryPolicy: $instance.memoryPolicy,
                            jvmProfile: $instance.jvmProfile,
                            customMemoryMb: $instance.customMemoryMb,
                            currentMemoryMb: instance.memoryMb,
                            customJvmArguments: instance.customJvmArguments,
                            lastSnapshot: instance.lastJvmTuningSnapshot,
                            lastKnownGood: instance.lastKnownGoodJvmTuning,
                            onRestoreAutomatic: restoreAutomaticTuning,
                            onRestoreLastKnownGood: restoreLastKnownGoodTuning
                        )
                        .disabled(usesGlobalRuntime.wrappedValue)
                    }
                }
            }

            ResourcesManagementPage(viewModel: viewModel)
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Apply version change?", chinese: "确认更改版本？", italian: "Applicare cambio versione?", french: "Appliquer le changement de version ?", spanish: "¿Aplicar cambio de versión?"),
            isPresented: $confirmApplyVersion,
            titleVisibility: .visible
        ) {
            Button(localizedString(theme.language, english: "Apply to \(instance.name)", chinese: "应用到 \(instance.name)", italian: "Applica a \(instance.name)", french: "Appliquer à \(instance.name)", spanish: "Aplicar a \(instance.name)")) {
                applyVersionChange()
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            Text(versionChangeSummary)
        }
        .confirmationDialog(
            pendingStorageAction?.title(language: theme.language) ?? "",
            isPresented: storageDialogPresented,
            titleVisibility: .visible
        ) {
            if let action = pendingStorageAction {
                Button(action.confirmTitle(language: theme.language), role: action.role) {
                    mutateVersionStorage(action)
                    pendingStorageAction = nil
                }
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            if let action = pendingStorageAction {
                Text(action.message(version: version?.id ?? "-", language: theme.language))
            }
        }
        .task {
            if viewModel.managedJavaRuntimes.isEmpty {
                viewModel.loadManagedJavaRuntimes()
            }
            if launcherSettings.autoDetectJava, viewModel.discoveredJavaRuntimes.isEmpty {
                viewModel.scanJavaRuntimes()
            }
        }
    }

    private var storageDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingStorageAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingStorageAction = nil
                }
            }
        )
    }

    @ViewBuilder
    private var versionStorageControls: some View {
        if let version {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    storageButtons(version)
                }
                VStack(alignment: .leading, spacing: 8) {
                    storageButtons(version)
                }
            }
        }
    }

    @ViewBuilder
    private func storageButtons(_ version: MinecraftVersionInfo) -> some View {
        GlassButton(
            systemImage: "archivebox",
            title: localizedString(theme.language, english: "Archive", chinese: "归档", italian: "Archivia", french: "Archiver", spanish: "Archivar")
        ) {
            pendingStorageAction = .archive
        }
        .disabled(!canArchive(version))

        GlassButton(
            systemImage: "arrow.up.bin",
            title: localizedString(theme.language, english: "Restore", chinese: "移出归档", italian: "Ripristina", french: "Restaurer", spanish: "Restaurar")
        ) {
            pendingStorageAction = .restore
        }
        .disabled(!version.isArchived || version.isInstalled)

        GlassButton(
            systemImage: "trash",
            title: AppText.delete.localized(theme.language)
        ) {
            pendingStorageAction = .delete
        }
        .disabled(!canDelete(version))
    }

    private var usesGlobalRuntime: Binding<Bool> {
        Binding(
            get: { instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            set: { useGlobal in
                if useGlobal {
                    instance.javaPath = ""
                    instance.memoryMb = SettingsStore.memoryMb
                    instance.memoryPolicy = .auto
                    instance.jvmProfile = .auto
                } else {
                    instance.javaPath = "java"
                }
            }
        )
    }

    private func restoreAutomaticTuning() {
        instance.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb)
    }

    private func restoreLastKnownGoodTuning(_ snapshot: JvmTuningSnapshot) {
        instance.applyJvmTuningSnapshot(snapshot)
    }

    private var compatibleLoaders: [LoaderKind] {
        guard let version else { return LoaderKind.allCases }
        return version.kind == .oldAlpha || version.kind == .oldBeta ? [] : LoaderKind.allCases
    }

    private var canApplyVersion: Bool {
        guard let version else { return false }
        return version.id != instance.minecraftVersion && version.isInstalled
    }

    private var versionChangeSummary: String {
        guard let version else { return "" }
        return localizedString(
            theme.language,
            english: "\(instance.name) will change from Minecraft \(instance.minecraftVersion) to Minecraft \(version.id). Loader and local content may need review.",
            chinese: "\(instance.name) 将从 Minecraft \(instance.minecraftVersion) 更改为 Minecraft \(version.id)。Loader 和本地内容可能需要重新检查。",
            italian: "\(instance.name) passerà da Minecraft \(instance.minecraftVersion) a Minecraft \(version.id).",
            french: "\(instance.name) passera de Minecraft \(instance.minecraftVersion) à Minecraft \(version.id).",
            spanish: "\(instance.name) cambiará de Minecraft \(instance.minecraftVersion) a Minecraft \(version.id)."
        )
    }

    private var versionStateTitle: String {
        guard let version else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        if version.isInstalled {
            return localizedString(theme.language, english: "Installed", chinese: "已安装", italian: "Installata", french: "Installée", spanish: "Instalada")
        }
        if version.isArchived {
            return localizedString(theme.language, english: "Archived", chinese: "已归档", italian: "Archiviata", french: "Archivée", spanish: "Archivada")
        }
        return localizedString(theme.language, english: "Needs Install", chinese: "需要安装", italian: "Da installare", french: "À installer", spanish: "Por instalar")
    }

    private var versionBadgeStyle: StatusBadge.Style {
        guard let version else { return .running }
        if version.isArchived { return .neutral }
        return version.isInstalled ? .success : .warning
    }

    private func versionMetric(_ title: String, _ value: String, _ systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }

    private func applyInstanceRuntime() {
        viewModel.version = instance.minecraftVersion
        viewModel.memoryMb = usesGlobalRuntime.wrappedValue ? SettingsStore.memoryMb : instance.memoryMb
        viewModel.javaPath = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SettingsStore.javaPath : instance.javaPath
        if let loader = instance.loader {
            versionStore.selectedLoader = loader
        }
    }

    private func repairFocusedVersion() {
        viewModel.version = version?.id ?? instance.minecraftVersion
        viewModel.memoryMb = usesGlobalRuntime.wrappedValue ? SettingsStore.memoryMb : instance.memoryMb
        viewModel.javaPath = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SettingsStore.javaPath : instance.javaPath
        viewModel.install(gameDir: instance.gameDirectory)
    }

    private func applyVersionChange() {
        guard let version else { return }
        instance.minecraftVersion = version.id
        if !compatibleLoaders.contains(where: { Optional($0) == instance.loader }) {
            instance.loader = nil
        }
        applyInstanceRuntime()
        versionStore.refreshAssets(for: instance)
    }

    private func canArchive(_ version: MinecraftVersionInfo) -> Bool {
        version.isInstalled && !version.isUsedByInstance
    }

    private func canDelete(_ version: MinecraftVersionInfo) -> Bool {
        (version.isInstalled || version.isArchived) && !version.isUsedByInstance
    }

    private func mutateVersionStorage(_ action: VersionStorageConfirmation) {
        guard let version else { return }
        versionStore.mutateVersionStorage(
            version,
            action: action.coreAction,
            instances: instanceStore.instances,
            settings: launcherSettings
        )
    }
}

private enum VersionStorageConfirmation: String, Identifiable {
    case delete
    case archive
    case restore

    var id: String { rawValue }

    var role: ButtonRole? {
        self == .delete ? .destructive : nil
    }

    var coreAction: CoreMinecraftVersionStorageAction {
        switch self {
        case .delete:
            return .delete
        case .archive:
            return .archive
        case .restore:
            return .restore
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .delete:
            return localizedString(language, english: "Delete Minecraft version?", chinese: "删除 Minecraft 版本？", italian: "Eliminare versione?", french: "Supprimer la version ?", spanish: "¿Eliminar versión?")
        case .archive:
            return localizedString(language, english: "Archive Minecraft version?", chinese: "归档 Minecraft 版本？", italian: "Archiviare versione?", french: "Archiver la version ?", spanish: "¿Archivar versión?")
        case .restore:
            return localizedString(language, english: "Restore archived version?", chinese: "移出归档版本？", italian: "Ripristinare versione?", french: "Restaurer la version ?", spanish: "¿Restaurar versión?")
        }
    }

    func confirmTitle(language: AppLanguage) -> String {
        switch self {
        case .delete:
            return AppText.delete.localized(language)
        case .archive:
            return localizedString(language, english: "Archive", chinese: "归档", italian: "Archivia", french: "Archiver", spanish: "Archivar")
        case .restore:
            return localizedString(language, english: "Restore", chinese: "移出归档", italian: "Ripristina", french: "Restaurer", spanish: "Restaurar")
        }
    }

    func message(version: String, language: AppLanguage) -> String {
        switch self {
        case .delete:
            return localizedString(language, english: "Minecraft \(version) will be moved to Trash. Game configurations using this version are blocked from deletion.", chinese: "Minecraft \(version) 将移入废纸篓。正在被游戏配置使用的版本无法删除。", italian: "Minecraft \(version) verrà spostato nel Cestino.", french: "Minecraft \(version) sera placé dans la corbeille.", spanish: "Minecraft \(version) se moverá a la papelera.")
        case .archive:
            return localizedString(language, english: "Minecraft \(version) will be compressed into an archive and the installed folder will be removed to save space.", chinese: "Minecraft \(version) 将压缩为归档包，并删除已安装文件夹以节省空间。", italian: "Minecraft \(version) verrà compresso in archivio.", french: "Minecraft \(version) sera compressé en archive.", spanish: "Minecraft \(version) se comprimirá en un archivo.")
        case .restore:
            return localizedString(language, english: "Minecraft \(version) will be extracted from the archive. The archive file will be removed after a successful restore.", chinese: "Minecraft \(version) 将从归档包解压移出；成功后会删除归档压缩包。", italian: "Minecraft \(version) verrà estratto dall'archivio.", french: "Minecraft \(version) sera extrait de l'archive.", spanish: "Minecraft \(version) se extraerá del archivo.")
        }
    }
}

private struct InstanceVersionResourcePanel: View {
    let instance: GameInstance
    let refresh: () -> Void
    let openResources: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizedString(theme.language, english: "Installed Content", chinese: "已安装内容", italian: "Contenuto installato", french: "Contenu installé", spanish: "Contenido instalado"))
                    .font(.headline)
                Spacer()
                Picker("", selection: $versionStore.selectedAssetKind) {
                    ForEach(ManagedAssetKind.allCases) { kind in
                        Text(kind.title(language: theme.language)).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 360)
            }

            if versionStore.managedAssets.isEmpty {
                ContentUnavailableView(
                    AppText.noItems.localized(theme.language, versionStore.selectedAssetKind.title(language: theme.language)),
                    systemImage: "tray",
                    description: Text(versionStore.fileStatus)
                )
                .frame(minHeight: 120)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(versionStore.managedAssets.prefix(6)) { asset in
                        InstanceVersionResourcePreviewRow(asset: asset)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    resourceActions
                }
                VStack(alignment: .leading, spacing: 8) {
                    resourceActions
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: versionStore.selectedAssetKind) {
            refresh()
        }
    }

    @ViewBuilder
    private var resourceActions: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refresh)
        GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
            FinderIntegration.openManagedFolder(kind: versionStore.selectedAssetKind, instance: instance)
        }
        GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Manage All", chinese: "管理全部", italian: "Gestisci tutto", french: "Tout gérer", spanish: "Gestionar todo"), action: openResources)
        GlassButton(systemImage: "magnifyingglass.circle", title: localizedString(theme.language, english: "Find More", chinese: "查找更多", italian: "Trova altro", french: "En trouver plus", spanish: "Buscar más"), action: openDiscover)
    }
}
