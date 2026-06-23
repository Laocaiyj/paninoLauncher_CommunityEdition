import SwiftUI

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
