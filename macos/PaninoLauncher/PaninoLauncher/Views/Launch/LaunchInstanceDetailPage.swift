import SwiftUI

enum LaunchInstanceDetailTab: String, CaseIterable, Identifiable {
    case overview
    case content
    case version
    case saves
    case settings
    case backup

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            return localizedString(language, english: "Overview", chinese: "概览", italian: "Panoramica", french: "Aperçu", spanish: "Resumen")
        case .content:
            return localizedString(language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido")
        case .version:
            return localizedString(language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión")
        case .saves:
            return localizedString(language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas")
        case .settings:
            return localizedString(language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes")
        case .backup:
            return localizedString(language, english: "Backup", chinese: "备份", italian: "Backup", french: "Sauvegarde", spanish: "Copia")
        }
    }
}

private struct PendingLockfileReview: Identifiable {
    let id = UUID()
    let policy: String
    let result: CoreLockfileSolverResult
}

struct LaunchInstanceDetailPage: View {
    let instance: GameInstance
    @ObservedObject var viewModel: LauncherViewModel
    let summary: CoreLaunchInstanceSummary?
    let statusTitle: String
    let statusStyle: StatusBadge.Style
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let back: () -> Void
    let launch: () -> Void
    let cancel: () -> Void
    let openContent: () -> Void
    let openDiscover: () -> Void
    let openSettings: () -> Void
    let openVersionManagement: () -> Void
    let backupSaves: () -> Void
    let exportInstance: () -> Void
    let toggleFavorite: () -> Void
    let updateAppearance: (UUID, InstanceAppearanceValues) -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var selectedTab: LaunchInstanceDetailTab = .overview
    @State private var appearanceTarget: GameInstance?
    @State private var currentLockfile: CorePaninoLockfile?
    @State private var lockfileVerify: CoreLockfileVerifyResponse?
    @State private var lockfileStatusMessage = ""
    @State private var lockfileBusy = false
    @State private var pendingLockfileReview: PendingLockfileReview?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailHeader

            HStack(alignment: .top, spacing: 16) {
                tabSidebar
                    .frame(width: 210, alignment: .topLeading)
                tabContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .sheet(item: $appearanceTarget) { target in
            InstanceAppearanceEditor(instance: target) { values in
                updateAppearance(target.id, values)
            }
            .environmentObject(theme)
        }
        .sheet(item: $pendingLockfileReview) { review in
            LockfileReviewSheet(
                result: review.result,
                title: lockfileReviewTitle(for: review.policy),
                subtitle: lockfileReviewSubtitle(for: review.result),
                confirmTitle: localizedString(theme.language, english: "Apply", chinese: "应用", italian: "Applica", french: "Appliquer", spanish: "Aplicar"),
                onCancel: { pendingLockfileReview = nil },
                onConfirm: { applyLockfileReview(review) }
            )
            .environmentObject(theme)
        }
        .task(id: instance.gameDirectory) {
            await refreshLockfileState()
        }
    }

    private var detailHeader: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: back) {
                        Label(localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Volver"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(instance.name)
                                .font(.title2.bold())
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        MetadataLine(items: instance.metadataLine(language: theme.language))
                    }

                    Spacer()
                    LaunchPetPlaceholder()
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { headerActions }
                    VStack(alignment: .leading, spacing: 10) { headerActions }
                }
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        GlassButton(systemImage: primarySystemImage, title: primaryTitle, prominent: true, action: launch)
            .disabled(primaryDisabled)
        if canCancel {
            GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: cancel)
        }
        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
            FinderIntegration.openInstanceDirectory(instance)
        }
        GlassButton(systemImage: "paintpalette", title: localizedString(theme.language, english: "Appearance", chinese: "外观", italian: "Aspetto", french: "Apparence", spanish: "Apariencia")) {
            appearanceTarget = instance
        }
        GlassButton(systemImage: instance.isFavorite ? "star.slash" : "star", title: instance.isFavorite ? localizedString(theme.language, english: "Unpin", chinese: "取消收藏", italian: "Sblocca", french: "Retirer", spanish: "Quitar") : localizedString(theme.language, english: "Pin", chinese: "收藏", italian: "Fissa", french: "Épingler", spanish: "Fijar"), action: toggleFavorite)
    }

    private var tabSidebar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(LaunchInstanceDetailTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title(language: theme.language))
                            .font(.callout.weight(selectedTab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                            .padding(.horizontal, 12)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? Color.white : .primary)
                    .background(selectedTab == tab ? theme.semanticSelectionColor : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .content:
            contentContent
        case .version:
            versionContent
        case .saves:
            savesContent
        case .settings:
            settingsContent
        case .backup:
            backupContent
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            summaryPanel
            lockfileStatusPanel
            managementPanel
        }
    }

    private var summaryPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Summary", chinese: "摘要", italian: "Riepilogo", french: "Résumé", spanish: "Resumen"))
                    .font(.headline)
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "État", spanish: "Estado"), value: statusTitle)
                    LaunchMetric(title: localizedString(theme.language, english: "Last Launch", chinese: "最近启动", italian: "Ultimo avvio", french: "Dernier lancement", spanish: "Último inicio"), value: instance.lastLaunchedAt?.formatted(date: .abbreviated, time: .shortened) ?? localizedString(theme.language, english: "Never", chinese: "从未", italian: "Mai", french: "Jamais", spanish: "Nunca"))
                    LaunchMetric(title: localizedString(theme.language, english: "Play Time", chinese: "游戏时长", italian: "Tempo gioco", french: "Temps de jeu", spanish: "Tiempo jugado"), value: formattedPlayDuration(instance.totalPlaySeconds ?? 0, language: theme.language))
                    LaunchMetric(title: localizedString(theme.language, english: "Launches", chinese: "启动次数", italian: "Avvii", french: "Lancements", spanish: "Inicios"), value: "\(instance.launchCount)")
                }
            }
        }
    }

    private var managementPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Manage", chinese: "管理", italian: "Gestisci", french: "Gérer", spanish: "Gestionar"))
                    .font(.headline)
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    detailAction(title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido"), subtitle: contentOverview, action: { selectedTab = .content })
                    detailAction(title: localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), subtitle: "Minecraft \(instance.minecraftVersion)", action: { selectedTab = .version })
                    detailAction(title: localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"), subtitle: "\(summary?.content.saveCount ?? 0)", action: { selectedTab = .saves })
                    detailAction(title: localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"), subtitle: "\(instance.memoryMb) MB", action: { selectedTab = .settings })
                }
            }
        }
    }

    private var lockfileStatusPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(localizedString(theme.language, english: "Lockfile", chinese: "锁文件", italian: "Lockfile", french: "Lockfile", spanish: "Lockfile"), systemImage: "lock.doc")
                        .font(.headline)
                    Spacer()
                    StatusBadge(title: lockfileStatusTitle, style: lockfileBadgeStyle)
                }
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: "\(currentLockfile?.files.count ?? 0)")
                    LaunchMetric(title: localizedString(theme.language, english: "Drift", chinese: "漂移", italian: "Deriva", french: "Dérive", spanish: "Deriva"), value: "\(lockfileVerify?.lockfileDrift.count ?? 0)")
                    LaunchMetric(title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar"), value: lockfileVerify?.repairPlan == nil ? "-" : localizedString(theme.language, english: "Ready", chinese: "可用", italian: "Pronto", french: "Prêt", spanish: "Listo"))
                    LaunchMetric(title: localizedString(theme.language, english: "Manual", chinese: "手动", italian: "Manuale", french: "Manuel", spanish: "Manual"), value: "\(manualChangeCount)")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { lockfileActionButtons }
                    VStack(alignment: .leading, spacing: 10) { lockfileActionButtons }
                }
                if !lockfileStatusMessage.isEmpty {
                    Text(lockfileStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .paninoTruncation(.summary(lines: 2))
                }
            }
        }
    }

    @ViewBuilder
    private var lockfileActionButtons: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
            Task { await refreshLockfileState() }
        }
        .disabled(lockfileBusy)
        if lockfileVerify?.repairPlan != nil {
            GlassButton(systemImage: "wrench.and.screwdriver", title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar")) {
                Task { await prepareLockfileReview(policy: "repair") }
            }
            .disabled(lockfileBusy)
        }
    }

    private var lockfileUpdatePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Lockfile Updates", chinese: "锁文件更新", italian: "Aggiornamenti lockfile", french: "Mises à jour lockfile", spanish: "Actualizaciones lockfile"))
                    .font(.headline)
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    updatePolicyButton(policy: "keepLocked", systemImage: "lock", title: localizedString(theme.language, english: "Keep Locked", chinese: "保持锁定", italian: "Mantieni bloccato", french: "Garder verrouillé", spanish: "Mantener fijado"))
                    updatePolicyButton(policy: "updateSelected", systemImage: "checklist.checked", title: localizedString(theme.language, english: "Update Selected", chinese: "只更新选中项", italian: "Aggiorna selezionati", french: "Mettre à jour sélection", spanish: "Actualizar selección"))
                    updatePolicyButton(policy: "updateAllSafe", systemImage: "shield.checkered", title: localizedString(theme.language, english: "Update All Safe", chinese: "安全更新全部", italian: "Aggiorna sicuro", french: "Tout mettre à jour sûr", spanish: "Actualizar seguro"))
                    updatePolicyButton(policy: "relock", systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Relock", chinese: "重新锁定", italian: "Riblocca", french: "Reverrouiller", spanish: "Rebloquear"))
                }
            }
        }
    }

    private func updatePolicyButton(policy: String, systemImage: String, title: String) -> some View {
        Button {
            Task { await prepareLockfileReview(policy: policy) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(updatePolicySubtitle(policy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(lockfileBusy)
    }

    private var contentContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localizedString(theme.language, english: "Installed Content", chinese: "已安装内容", italian: "Contenuto installato", french: "Contenu installé", spanish: "Contenido instalado"))
                        .font(.headline)
                    LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                        LaunchMetric(title: "Mods", value: "\(summary?.content.modCount ?? 0)")
                        LaunchMetric(title: localizedString(theme.language, english: "Resource Packs", chinese: "资源包", italian: "Pacchetti risorse", french: "Packs de ressources", spanish: "Paquetes de recursos"), value: "\(summary?.content.resourcePackCount ?? 0)")
                        LaunchMetric(title: localizedString(theme.language, english: "Shaders", chinese: "光影包", italian: "Shader", french: "Shaders", spanish: "Shaders"), value: "\(summary?.content.shaderPackCount ?? 0)")
                        LaunchMetric(title: localizedString(theme.language, english: "Warnings", chinese: "警告", italian: "Avvisi", french: "Alertes", spanish: "Avisos"), value: "\(summary?.content.warningCount ?? 0)")
                    }
                    HStack(spacing: 10) {
                        GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Manage Content", chinese: "管理内容", italian: "Gestisci contenuti", french: "Gérer contenu", spanish: "Gestionar contenido"), action: openContent)
                        GlassButton(systemImage: "arrow.down.circle", title: localizedString(theme.language, english: "Install Online", chinese: "在线安装", italian: "Installa online", french: "Installer en ligne", spanish: "Instalar online"), action: openDiscover)
                        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
                            FinderIntegration.openManagedFolder(kind: .mods, instance: instance)
                        }
                        .disabled(instance.loader == nil)
                    }
                }
            }
            lockfileUpdatePanel
        }
    }

    private var versionContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Version and Loader", chinese: "版本与加载器", italian: "Versione e loader", french: "Version et chargeur", spanish: "Versión y cargador"))
                    .font(.headline)
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: "Minecraft", value: instance.minecraftVersion)
                    LaunchMetric(title: localizedString(theme.language, english: "Loader"), value: instance.loaderTitle(language: theme.language))
                    LaunchMetric(title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: summary?.status ?? instance.status.rawValue)
                    LaunchMetric(title: localizedString(theme.language, english: "Disk", chinese: "磁盘", italian: "Disco", french: "Disque", spanish: "Disco"), value: formattedBytes(summary?.diskUsageBytes))
                }
                HStack(spacing: 10) {
                    GlassButton(systemImage: "square.stack.3d.up", title: localizedString(theme.language, english: "Manage Versions", chinese: "版本管理", italian: "Gestisci versioni", french: "Gérer versions", spanish: "Gestionar versiones"), action: openVersionManagement)
                    GlassButton(systemImage: primarySystemImage, title: primaryTitle, action: launch)
                        .disabled(primaryDisabled)
                    GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
                        FinderIntegration.openInstanceDirectory(instance)
                    }
                }
            }
        }
    }

    private var savesContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"))
                    .font(.headline)
                LaunchMetric(title: localizedString(theme.language, english: "Detected Saves", chinese: "已检测存档", italian: "Salvataggi rilevati", french: "Sauvegardes détectées", spanish: "Partidas detectadas"), value: "\(summary?.content.saveCount ?? 0)")
                    .frame(maxWidth: 240)
                HStack(spacing: 10) {
                    GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Saves Folder", chinese: "打开存档文件夹", italian: "Apri salvataggi", french: "Ouvrir sauvegardes", spanish: "Abrir partidas")) {
                        FinderIntegration.openSavesDirectory(instance)
                    }
                    GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup", chinese: "备份", italian: "Backup", french: "Sauvegarder", spanish: "Respaldar"), action: { selectedTab = .backup })
                }
            }
        }
    }

    private var settingsContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Run Settings", chinese: "运行设置", italian: "Impostazioni avvio", french: "Réglages d'exécution", spanish: "Ajustes de ejecución"))
                    .font(.headline)
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: "Java", value: instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedString(theme.language, english: "Automatic", chinese: "自动", italian: "Automatico", french: "Automatique", spanish: "Automático") : instance.javaPath)
                    LaunchMetric(title: localizedString(theme.language, english: "Memory", chinese: "内存", italian: "Memoria", french: "Mémoire", spanish: "Memoria"), value: "\(instance.memoryMb) MB")
                    LaunchMetric(title: localizedString(theme.language, english: "JVM Args", chinese: "JVM 参数", italian: "Argomenti JVM", french: "Arguments JVM", spanish: "Argumentos JVM"), value: instance.jvmArguments.isEmpty ? "-" : instance.jvmArguments)
                }
                GlassButton(systemImage: "gearshape", title: localizedString(theme.language, english: "Open Settings", chinese: "打开设置", italian: "Apri impostazioni", french: "Ouvrir réglages", spanish: "Abrir ajustes"), action: openSettings)
            }
        }
    }

    private var backupContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Backup and Export", chinese: "备份与导出", italian: "Backup ed esportazione", french: "Sauvegarde et export", spanish: "Copia y exportación"))
                    .font(.headline)
                Text(localizedString(theme.language, english: "Preflight checks and archive/export work are delegated to Core.", chinese: "预检、压缩和导出由 Core 处理。", italian: "Controlli e archivi sono gestiti dal Core.", french: "Les contrôles et archives sont gérés par Core.", spanish: "Las comprobaciones y archivos las gestiona Core."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup Saves", chinese: "备份存档", italian: "Backup salvataggi", french: "Sauvegarder", spanish: "Respaldar partidas"), action: backupSaves)
                    GlassButton(systemImage: "square.and.arrow.up", title: localizedString(theme.language, english: "Export Instance", chinese: "导出实例", italian: "Esporta istanza", french: "Exporter instance", spanish: "Exportar instancia"), action: exportInstance)
                }
            }
        }
    }

    private var detailMetricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)]
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)]
    }

    private var manualChangeCount: Int {
        guard let lockfileVerify else { return 0 }
        return lockfileVerify.manualFiles.count + lockfileVerify.extraFiles.count
    }

    private var lockfileStatusTitle: String {
        if lockfileBusy {
            return localizedString(theme.language, english: "Checking", chinese: "检查中", italian: "Controllo", french: "Vérification", spanish: "Comprobando")
        }
        if needsRelock {
            return localizedString(theme.language, english: "Needs Relock", chinese: "需要重解", italian: "Da ribloccare", french: "À reverrouiller", spanish: "Rebloquear")
        }
        guard let lockfileVerify else {
            return currentLockfile == nil
                ? localizedString(theme.language, english: "No Lock", chinese: "未锁定", italian: "Nessun lock", french: "Non verrouillé", spanish: "Sin lock")
                : localizedString(theme.language, english: "Unknown", chinese: "未知", italian: "Sconosciuto", french: "Inconnu", spanish: "Desconocido")
        }
        if lockfileVerify.repairPlan != nil {
            return localizedString(theme.language, english: "Repairable", chinese: "可修复", italian: "Riparabile", french: "Réparable", spanish: "Reparable")
        }
        if manualChangeCount > 0 {
            return localizedString(theme.language, english: "Manual Changes", chinese: "手动修改", italian: "Modifiche manuali", french: "Modifications", spanish: "Cambios manuales")
        }
        if lockfileVerify.status == "locked" {
            return localizedString(theme.language, english: "Locked", chinese: "已锁定", italian: "Bloccato", french: "Verrouillé", spanish: "Bloqueado")
        }
        return localizedString(theme.language, english: "Drifted", chinese: "有漂移", italian: "Deriva", french: "Dérive", spanish: "Deriva")
    }

    private var lockfileBadgeStyle: StatusBadge.Style {
        if lockfileBusy { return .download }
        if needsRelock || lockfileVerify?.repairPlan != nil { return .warning }
        if manualChangeCount > 0 || lockfileVerify?.status == "drifted" { return .warning }
        return currentLockfile == nil ? .neutral : .success
    }

    private var needsRelock: Bool {
        guard let currentLockfile else { return false }
        if let minecraft = currentLockfile.minecraft, minecraft != instance.contentMinecraftVersion {
            return true
        }
        if let family = currentLockfile.loader?.family, family != instance.loader?.rawValue {
            return true
        }
        return false
    }

    @MainActor
    private func refreshLockfileState() async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
            currentLockfile = current.lockfile
            if let lockfile = current.lockfile {
                lockfileVerify = try await viewModel.verifyLockfile(CoreLockfileVerifyRequest(targetGameDir: instance.gameDirectory, lockfile: lockfile))
                lockfileStatusMessage = ""
            } else {
                lockfileVerify = nil
                lockfileStatusMessage = localizedString(theme.language, english: "No panino-lock.json exists for this instance.", chinese: "此实例还没有 panino-lock.json。", italian: "Nessun panino-lock.json per questa istanza.", french: "Aucun panino-lock.json pour cette instance.", spanish: "No hay panino-lock.json para esta instancia.")
            }
        } catch {
            lockfileVerify = nil
            lockfileStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareLockfileReview(policy: String) async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            if currentLockfile == nil {
                let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
                currentLockfile = current.lockfile
            }
            let request = CoreLockfileSolveRequest(
                mode: policy == "repair" ? "repair" : "update",
                targetGameDir: instance.gameDirectory,
                minecraftVersion: instance.contentMinecraftVersion,
                loader: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                existingLockfile: currentLockfile,
                updatePolicy: policy
            )
            let result = try await viewModel.solveLockfile(request)
            pendingLockfileReview = PendingLockfileReview(policy: policy, result: result)
            lockfileStatusMessage = ""
        } catch {
            lockfileStatusMessage = error.localizedDescription
        }
    }

    private func applyLockfileReview(_ review: PendingLockfileReview) {
        guard let lockfile = review.result.lockfile else { return }
        Task {
            do {
                _ = try await viewModel.applyLockfile(
                    CoreLockfileApplyRequest(
                        targetGameDir: instance.gameDirectory,
                        solverFingerprint: lockfile.fingerprint,
                        result: review.result
                    )
                )
                pendingLockfileReview = nil
                lockfileStatusMessage = localizedString(theme.language, english: "Lockfile applied.", chinese: "锁文件已应用。", italian: "Lockfile applicato.", french: "Lockfile appliqué.", spanish: "Lockfile aplicado.")
                await refreshLockfileState()
            } catch {
                lockfileStatusMessage = error.localizedDescription
            }
        }
    }

    private func updatePolicySubtitle(_ policy: String) -> String {
        switch policy {
        case "updateSelected":
            return localizedString(theme.language, english: "Selected packages and required dependencies.", chinese: "选中项目及必需依赖。", italian: "Elementi selezionati e dipendenze.", french: "Sélection et dépendances.", spanish: "Selección y dependencias.")
        case "updateAllSafe":
            return localizedString(theme.language, english: "Compatible updates only.", chinese: "只接受兼容更新。", italian: "Solo aggiornamenti compatibili.", french: "Mises à jour compatibles.", spanish: "Solo compatibles.")
        case "relock":
            return localizedString(theme.language, english: "Resolve from current inputs.", chinese: "按当前输入重新求解。", italian: "Risolvi dagli input attuali.", french: "Résoudre depuis les entrées.", spanish: "Resolver de nuevo.")
        default:
            return localizedString(theme.language, english: "Preserve existing locked packages.", chinese: "保留已锁定内容。", italian: "Mantieni pacchetti bloccati.", french: "Conserver le verrou.", spanish: "Conservar bloqueados.")
        }
    }

    private func lockfileReviewTitle(for policy: String) -> String {
        switch policy {
        case "repair":
            return localizedString(theme.language, english: "Review repair plan", chinese: "确认修复计划", italian: "Controlla riparazione", french: "Vérifier réparation", spanish: "Revisar reparación")
        case "updateSelected":
            return localizedString(theme.language, english: "Review selected update", chinese: "确认选中更新", italian: "Controlla selezionati", french: "Vérifier sélection", spanish: "Revisar selección")
        case "updateAllSafe":
            return localizedString(theme.language, english: "Review safe update", chinese: "确认安全更新", italian: "Controlla aggiornamento sicuro", french: "Vérifier mise à jour sûre", spanish: "Revisar actualización segura")
        case "relock":
            return localizedString(theme.language, english: "Review relock", chinese: "确认重新锁定", italian: "Controlla riblocco", french: "Vérifier reverrouillage", spanish: "Revisar rebloqueo")
        default:
            return localizedString(theme.language, english: "Review lockfile", chinese: "确认锁文件", italian: "Controlla lockfile", french: "Vérifier lockfile", spanish: "Revisar lockfile")
        }
    }

    private func lockfileReviewSubtitle(for result: CoreLockfileSolverResult) -> String {
        let changes = result.changeset.add.count + result.changeset.replace.count + result.changeset.remove.count + result.changeset.repair.count
        let deps = result.lockfile?.constraints.filter { $0.required && $0.relation == "requires" }.count ?? 0
        return localizedString(theme.language, english: "\(changes) changes · \(deps) required dependencies", chinese: "\(changes) 个变更 · \(deps) 个必需依赖", italian: "\(changes) cambi · \(deps) dipendenze", french: "\(changes) changements · \(deps) dépendances", spanish: "\(changes) cambios · \(deps) dependencias")
    }

    private var contentOverview: String {
        guard let content = summary?.content else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        return "\(content.modCount) Mods · \(content.resourcePackCount) RP · \(content.shaderPackCount) Shaders"
    }

    private func detailAction(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func formattedBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "-" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
