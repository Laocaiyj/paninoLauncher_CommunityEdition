import SwiftUI

struct LaunchInstanceDetailHeader: View {
    let instance: GameInstance
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let back: () -> Void
    let launch: () -> Void
    let cancel: () -> Void
    let editAppearance: () -> Void
    let toggleFavorite: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: back) {
                        Label(localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Volver"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(instance.name)
                            .font(.title2.bold())
                            .lineLimit(1)
                            .truncationMode(.tail)
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
        GlassButton(systemImage: "paintpalette", title: localizedString(theme.language, english: "Appearance", chinese: "外观", italian: "Aspetto", french: "Apparence", spanish: "Apariencia"), action: editAppearance)
        GlassButton(
            systemImage: instance.isFavorite ? "star.slash" : "star",
            title: instance.isFavorite
                ? localizedString(theme.language, english: "Unpin", chinese: "取消收藏", italian: "Sblocca", french: "Retirer", spanish: "Quitar")
                : localizedString(theme.language, english: "Pin", chinese: "收藏", italian: "Fissa", french: "Épingler", spanish: "Fijar"),
            action: toggleFavorite
        )
    }
}

struct LaunchInstanceDetailSidebar: View {
    @Binding var selectedTab: LaunchInstanceDetailTab
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}

struct LaunchInstanceSummaryPanel: View {
    let instance: GameInstance
    let statusTitle: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}

struct LaunchInstanceManagementPanel: View {
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let showContent: () -> Void
    let showVersion: () -> Void
    let showSaves: () -> Void
    let showSettings: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Manage", chinese: "管理", italian: "Gestisci", french: "Gérer", spanish: "Gestionar"))
                    .font(.headline)
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido"), subtitle: contentOverview, action: showContent)
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), subtitle: "Minecraft \(instance.minecraftVersion)", action: showVersion)
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"), subtitle: "\(summary?.content.saveCount ?? 0)", action: showSaves)
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"), subtitle: "\(instance.memoryMb) MB", action: showSettings)
                }
            }
        }
    }

    private var contentOverview: String {
        guard let content = summary?.content else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        return "\(content.modCount) Mods · \(content.resourcePackCount) RP · \(content.shaderPackCount) Shaders"
    }
}

struct LaunchInstanceContentPanel: View {
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let openContent: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
    }
}

struct LaunchInstanceVersionPanel: View {
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let launch: () -> Void
    let openVersionManagement: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Version and Loader", chinese: "版本与加载器", italian: "Versione e loader", french: "Version et chargeur", spanish: "Versión y cargador"))
                    .font(.headline)
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: "Minecraft", value: instance.minecraftVersion)
                    LaunchMetric(title: localizedString(theme.language, english: "Loader"), value: instance.loaderTitle(language: theme.language))
                    LaunchMetric(title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: summary?.status ?? instance.status.rawValue)
                    LaunchMetric(title: localizedString(theme.language, english: "Disk", chinese: "磁盘", italian: "Disco", french: "Disque", spanish: "Disco"), value: optionalFormattedBytes(summary?.diskUsageBytes))
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
}

struct LaunchInstanceSavesPanel: View {
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let showBackup: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
                    GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup", chinese: "备份", italian: "Backup", french: "Sauvegarder", spanish: "Respaldar"), action: showBackup)
                }
            }
        }
    }
}

struct LaunchInstanceSettingsPanel: View {
    let instance: GameInstance
    let openSettings: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}

struct LaunchInstanceBackupPanel: View {
    let backupSaves: () -> Void
    let exportInstance: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}

private struct LaunchDetailActionTile: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
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
}

private var detailMetricColumns: [GridItem] {
    [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)]
}

private var actionColumns: [GridItem] {
    [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)]
}

private func optionalFormattedBytes(_ bytes: Int64?) -> String {
    bytes.map(formattedBytes) ?? "-"
}
