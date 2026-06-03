import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum InstanceSort: String, CaseIterable, Identifiable {
    case favoritesFirst
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favoritesFirst:
            return "Favorites First"
        case .name:
            return "Name"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .favoritesFirst:
            return localizedString(language, english: "Favorites First", chinese: "收藏优先", italian: "Preferiti prima", french: "Favoris d'abord", spanish: "Favoritos primero")
        case .name:
            return localizedString(language, english: "Name", chinese: "名称", italian: "Nome", french: "Nom", spanish: "Nombre")
        }
    }
}

private enum InstanceFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case needsAttention

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return localizedString(language, english: "All", chinese: "全部", italian: "Tutte", french: "Toutes", spanish: "Todas")
        case .favorites:
            return localizedString(language, english: "Favorites", chinese: "收藏", italian: "Preferite", french: "Favorites", spanish: "Favoritas")
        case .needsAttention:
            return localizedString(language, english: "Needs Attention", chinese: "需要处理", italian: "Da verificare", french: "À traiter", spanish: "Requieren atención")
        }
    }
}

private struct InstanceLibrarySidebar: View {
    @Binding var searchText: String
    @Binding var sort: InstanceSort
    @Binding var filter: InstanceFilter
    let counts: [InstanceFilter: Int]

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(showsShadow: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizedString(theme.language, english: "Library", chinese: "库", italian: "Libreria", french: "Bibliothèque", spanish: "Biblioteca"))
                    .font(.headline)
                    .lineLimit(1)

                PaninoTextInput(localizedString(theme.language, english: "Search installed instances", chinese: "搜索本地实例", italian: "Cerca istanze", french: "Rechercher instances", spanish: "Buscar instancias"), text: $searchText)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(InstanceFilter.allCases) { item in
                        InstanceCollectionRow(
                            filter: item,
                            count: counts[item] ?? 0,
                            selected: filter == item
                        ) {
                            filter = item
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Text(localizedString(theme.language, english: "Sort", chinese: "排序", italian: "Ordina", french: "Trier", spanish: "Ordenar"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker(localizedString(theme.language, english: "Sort"), selection: $sort) {
                        ForEach(InstanceSort.allCases) { sort in
                            Text(sort.title(language: theme.language)).tag(sort)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

private struct InstanceCollectionRow: View {
    let filter: InstanceFilter
    let count: Int
    let selected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(filter.title(language: theme.language))
                    .font(.callout.weight(selected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected ? Color.white.opacity(0.82) : .secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? theme.semanticSelectionColor : Color.clear, in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct InstanceLibraryGrid: View {
    let instances: [GameInstance]
    let selectedInstanceID: UUID?
    let canLaunch: Bool
    let selectInstance: (GameInstance) -> Void
    let launch: (GameInstance) -> Void
    let openProperties: (GameInstance, InstancePropertySection) -> Void
    let openFolder: (GameInstance) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
            ForEach(instances) { instance in
                InstanceLibraryTile(
                    instance: instance,
                    isSelected: selectedInstanceID == instance.id,
                    canLaunch: canLaunch,
                    selectInstance: selectInstance,
                    launch: launch,
                    openProperties: openProperties,
                    openFolder: openFolder
                )
            }
        }
    }
}

private struct InstanceLibraryTile: View {
    let instance: GameInstance
    let isSelected: Bool
    let canLaunch: Bool
    let selectInstance: (GameInstance) -> Void
    let launch: (GameInstance) -> Void
    let openProperties: (GameInstance, InstancePropertySection) -> Void
    let openFolder: (GameInstance) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InstanceCardCover(instance: instance)
                .frame(height: 108)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(instance.name)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        if instance.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.yellow)
                        }
                    }

                    MetadataLine(items: [
                        "Minecraft \(instance.minecraftVersion)",
                        instance.loaderTitle(language: theme.language)
                    ], font: .caption.weight(.medium))

                    Text("\(localizedString(theme.language, english: "Memory", chinese: "内存", italian: "Memoria", french: "Mémoire", spanish: "Memoria")) \(instance.memoryMb) MB")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 7) {
                    InstanceTileActionButton(
                        title: AppText.launch.localized(theme.language),
                        systemImage: "play.fill",
                        prominent: true
                    ) {
                        selectInstance(instance)
                        launch(instance)
                    }
                    .disabled(!canLaunch || !capabilities.canLaunch)

                    Spacer(minLength: 0)

                    InstanceTileActionButton(
                        title: localizedString(theme.language, english: "Properties", chinese: "属性", italian: "Proprietà", french: "Propriétés", spanish: "Propiedades"),
                        systemImage: "slider.horizontal.3"
                    ) {
                        selectInstance(instance)
                        openProperties(instance, .overview)
                    }

                    if let contentSection {
                        InstanceTileActionButton(
                            title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuti", french: "Contenu", spanish: "Contenido"),
                            systemImage: "shippingbox"
                        ) {
                            selectInstance(instance)
                            openProperties(instance, contentSection)
                        }
                    }

                    InstanceTileActionButton(
                        title: AppText.openFolder.localized(theme.language),
                        systemImage: "folder"
                    ) {
                        selectInstance(instance)
                        openFolder(instance)
                    }
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                .fill(isSelected ? theme.semanticSelectionColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.34))
        }
        .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                .strokeBorder(isSelected ? theme.semanticSelectionColor.opacity(0.62) : Color(nsColor: .separatorColor).opacity(0.36))
        }
        .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
        .onTapGesture {
            selectInstance(instance)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(instance.name), Minecraft \(instance.minecraftVersion), \(instance.status.title(language: theme.language))")
    }

    private var capabilities: GameConfigurationCapabilities {
        GameConfigurationCapabilities.capabilities(for: instance)
    }

    private var contentSection: InstancePropertySection? {
        if capabilities.canManageMods {
            return .mods
        }
        if capabilities.canManageResourcePacks {
            return .resourcePacks
        }
        if capabilities.canManageShaderPacks {
            return .shaders
        }
        return nil
    }
}

private struct InstanceCardCover: View {
    let instance: GameInstance
    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(instance.coverTintColor.opacity(0.14))
                Image(systemName: instance.resolvedIconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(instance.coverTintColor)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: instance.coverPath) {
            guard !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 560, height: 260))
        }
    }
}

private struct InstanceTileActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            if prominent {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
        }
        .buttonStyle(.plain)
        .font(.callout.weight(.semibold))
        .padding(.horizontal, prominent ? 11 : 0)
        .frame(minHeight: 30)
        .foregroundStyle(prominent ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                .fill(prominent ? theme.semanticSelectionColor.opacity(0.94) : Color(nsColor: .controlBackgroundColor).opacity(0.44))
                .strokeBorder(prominent ? Color.clear : Color(nsColor: .separatorColor).opacity(0.46))
        }
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct InstancePropertiesPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    @Binding var section: InstancePropertySection
    let openDiscover: () -> Void
    let onBack: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onMoveOut: () -> Void
    let onRestoreArchive: () -> Void

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        let activeSection = availableSections.contains(section) ? section : .overview
        HStack(alignment: .top, spacing: 16) {
            propertiesSidebar
                .frame(width: PaninoTokens.Layout.secondarySidebarWidth)

            VStack(alignment: .leading, spacing: 12) {
                GlassPanel {
                    HStack(spacing: 10) {
                        GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Atrás"), action: onBack)
                        PanelHeader(title: "Properties - \(instance.name)", systemImage: instance.iconName.isEmpty ? "cube.box.fill" : instance.iconName)
                        MetadataLine(items: ["Minecraft \(instance.minecraftVersion)", instance.loaderTitle(language: theme.language)])
                        Spacer()
                        if GameConfigurationCapabilities.capabilities(for: instance).canManageMods {
                            GlassButton(systemImage: "arrow.down.app", title: localizedString(theme.language, english: "Install Mods", chinese: "安装 Mod", italian: "Installa Mod", french: "Installer Mods", spanish: "Instalar Mods"), action: openDiscover)
                        }
                    }
                }

                switch activeSection {
                case .overview:
                    InstancePropertyOverview(
                        instance: $instance,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete,
                        onArchive: onArchive,
                        onMoveOut: onMoveOut,
                        onRestoreArchive: onRestoreArchive
                    )
                case .settings:
                    InstanceRuntimeSettingsPage(viewModel: viewModel, instance: $instance)
                case .mods, .resourcePacks, .shaders:
                    ResourcesManagementPage(viewModel: viewModel, openDiscover: openDiscover)
                        .task(id: section.id) {
                            if let kind = section.assetKind {
                                versionStore.selectedAssetKind = kind
                                versionStore.refreshAssets(for: instance)
                            }
                        }
                case .saves:
                    InstanceSavesPage(viewModel: viewModel, instance: instance)
                case .export:
                    InstanceExportPage(viewModel: viewModel, instance: instance)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var propertiesSidebar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(availableSections) { item in
                    Button {
                        section = item
                    } label: {
                        Text(item.title(language: theme.language))
                            .font(.callout.weight(section == item ? .semibold : .regular))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.controlMinSize, alignment: .leading)
                            .padding(.horizontal, 10)
                            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(section == item ? Color.white : Color.primary)
                    .background {
                        RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                            .fill(section == item ? theme.semanticSelectionColor : Color.clear)
                    }
                }
            }
        }
    }

    private var availableSections: [InstancePropertySection] {
        InstancePropertySection.availableSections(for: instance)
    }
}

private struct InstancePropertyOverview: View {
    @Binding var instance: GameInstance
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onMoveOut: () -> Void
    let onRestoreArchive: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var showAdvancedOptions = false

    var body: some View {
        let capabilities = GameConfigurationCapabilities.capabilities(for: instance)
        VStack(alignment: .leading, spacing: 12) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    PanelHeader(title: localizedString(theme.language, english: "Summary", chinese: "摘要", italian: "Riepilogo", french: "Résumé", spanish: "Resumen"), systemImage: "cube.box")
                    HStack(spacing: 12) {
                        CachedInstanceIcon(instance: instance)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(instance.name)
                                .font(.title3.bold())
                            MetadataLine(items: instance.metadataLine(language: theme.language))
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    PanelHeader(title: localizedString(theme.language, english: "Personalization", chinese: "个性化", italian: "Personalizzazione", french: "Personnalisation", spanish: "Personalización"), systemImage: "paintbrush")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                        SettingsRow(title: "Name", systemImage: "text.cursor") {
                            PaninoTextInput(localizedString(theme.language, english: "Configuration name", chinese: "游戏配置名称", italian: "Nome configurazione", french: "Nom de configuration", spanish: "Nombre de configuración"), text: $instance.name)
                        }
                        SettingsRow(title: "Group", systemImage: "folder.badge.gearshape") {
                            PaninoTextInput("Group", text: $instance.group)
                        }
                        SettingsRow(title: "Icon", systemImage: "photo") {
                            PaninoTextInput("SF Symbol name", text: $instance.iconName)
                        }
                        SettingsRow(title: "Favorite", systemImage: "star") {
                            Toggle("Pinned", isOn: $instance.isFavorite)
                                .toggleStyle(.switch)
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    PanelHeader(title: localizedString(theme.language, english: "Shortcuts", chinese: "快捷入口", italian: "Scorciatoie", french: "Raccourcis", spanish: "Accesos directos"), systemImage: "arrow.up.forward.square")
                    HStack(spacing: 8) {
                        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Configuration Folder", chinese: "配置文件夹", italian: "Cartella configurazione", french: "Dossier de configuration", spanish: "Carpeta de configuración")) {
                            FinderIntegration.openInstanceDirectory(instance)
                        }
                        GlassButton(systemImage: "tray.full", title: localizedString(theme.language, english: "Saves Folder", chinese: "存档文件夹", italian: "Cartella salvataggi", french: "Dossier sauvegardes", spanish: "Carpeta de partidas")) {
                            FinderIntegration.openSavesDirectory(instance)
                        }
                        if capabilities.canManageMods {
                            GlassButton(systemImage: "puzzlepiece.extension", title: "Mods Folder") {
                                FinderIntegration.openManagedFolder(kind: .mods, instance: instance)
                            }
                        }
                    }
                }
            }

            FullWidthDisclosureGroup(isExpanded: $showAdvancedOptions) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localizedString(theme.language, english: "Archive keeps the instance folder. Move Out archives it, removes the local folder, and lets you restore it later from the archive.", chinese: "归档会保留实例目录；移出会先归档再移除本地目录，之后可从归档恢复。", italian: "Archivia conserva la cartella; Sposta fuori archivia e rimuove la cartella locale.", french: "Archiver conserve le dossier ; Déplacer archive puis retire le dossier local.", spanish: "Archivar conserva la carpeta; Mover fuera archiva y elimina la carpeta local."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Archive Instance", chinese: "归档实例", italian: "Archivia istanza", french: "Archiver instance", spanish: "Archivar instancia"), action: onArchive)
                        GlassButton(systemImage: "externaldrive.badge.minus", title: localizedString(theme.language, english: "Move Out", chinese: "移出", italian: "Sposta fuori", french: "Déplacer", spanish: "Mover fuera"), action: onMoveOut)
                        GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Restore Archive", chinese: "恢复归档", italian: "Ripristina archivio", french: "Restaurer archive", spanish: "Restaurar archivo"), action: onRestoreArchive)
                        GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: onDelete)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text(localizedString(theme.language, english: "Advanced Options", chinese: "高级操作", italian: "Opzioni avanzate", french: "Options avancées", spanish: "Opciones avanzadas"))
                    .font(.headline)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct InstanceRuntimeSettingsPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance

    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        PanelHeader(title: localizedString(theme.language, english: "Runtime Settings", chinese: "运行设置", italian: "Impostazioni runtime", french: "Paramètres runtime", spanish: "Ajustes de runtime"), systemImage: "slider.horizontal.3")
                        Spacer()
                        Toggle(localizedString(theme.language, english: "Automatic defaults", chinese: "自动默认", italian: "Predefiniti automatici", french: "Défauts automatiques", spanish: "Valores automáticos"), isOn: usesGlobalRuntime)
                            .toggleStyle(.switch)
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

                    SettingsRow(title: AppText.loader.localized(theme.language), systemImage: "puzzlepiece.extension") {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(instance.loaderTitle(language: theme.language, includesVersion: true))
                                .font(.callout.weight(.semibold))
                            Text(localizedString(theme.language, english: "Loader changes use the install/preflight flow so Core can validate compatibility.", chinese: "Loader 变更必须走安装/预检流程，由 Core 判断兼容性。", italian: "Le modifiche loader passano dal Core.", french: "Les changements de loader passent par Core.", spanish: "Los cambios de loader pasan por Core."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
}

private struct InstanceExportPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let instance: GameInstance

    @EnvironmentObject private var theme: ThemeSettings
    @State private var preflight: CoreExportBackupPreflightResponse?
    @State private var preflightError = ""
    @State private var isCheckingPreflight = false
    @State private var actionStatus = ""
    @State private var isExporting = false

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: AppText.export.localized(theme.language), systemImage: "shippingbox.and.arrow.up")
                Text(localizedString(theme.language, english: "Export preflight and archive generation are handled by Haskell Core for this isolated instance directory.", chinese: "此隔离实例目录的导出预检与压缩包生成都由 Haskell Core 处理。", italian: "Preflight e archivio sono gestiti dal Core Haskell.", french: "Le précontrôle et l'archive sont gérés par le Core Haskell.", spanish: "La prevalidación y el archivo los gestiona Haskell Core."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                    exportMetric(localizedString(theme.language, english: "Configuration", chinese: "游戏配置", italian: "Configurazione", french: "Configuration", spanish: "Configuración"), instance.name)
                    exportMetric("Minecraft", instance.minecraftVersion)
                    exportMetric(localizedString(theme.language, english: "Loader"), instance.loaderTitle(language: theme.language))
                    exportMetric(localizedString(theme.language, english: "Directory"), effectiveGameDirectory)
                }

                HStack(spacing: 8) {
                    GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Run Preflight", chinese: "运行预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight")) {
                        runExportPreflight()
                    }
                    .disabled(isCheckingPreflight)
                    GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                        FinderIntegration.openInstanceDirectory(instance)
                    }
                    GlassButton(systemImage: "shippingbox.and.arrow.up", title: localizedString(theme.language, english: "Export Modpack", chinese: "导出整合包", italian: "Esporta modpack", french: "Exporter modpack", spanish: "Exportar modpack")) {
                        exportArchive(kind: "modpack")
                    }
                    .disabled(isExporting)
                    GlassButton(systemImage: "doc.zipper", title: localizedString(theme.language, english: "Export Zip", chinese: "导出压缩包", italian: "Esporta zip", french: "Exporter zip", spanish: "Exportar zip")) {
                        exportArchive(kind: "instance")
                    }
                    .disabled(isExporting)
                }

                PreflightResultView(preflight: preflight, error: preflightError, isChecking: isCheckingPreflight)
                if !actionStatus.isEmpty {
                    Text(actionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func runExportPreflight() {
        isCheckingPreflight = true
        preflightError = ""
        Task {
            do {
                let result = try await viewModel.exportBackupPreflight(for: instance, kind: "export")
                await MainActor.run {
                    preflight = result
                    isCheckingPreflight = false
                }
            } catch {
                await MainActor.run {
                    preflight = nil
                    preflightError = error.localizedDescription
                    isCheckingPreflight = false
                }
            }
        }
    }

    private func exportMetric(_ title: String, _ value: String) -> some View {
        HStack(spacing: 0) {
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

    private var effectiveGameDirectory: String {
        instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func exportArchive(kind: String) {
        guard !effectiveGameDirectory.isEmpty else {
            actionStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isExporting = true
        actionStatus = localizedString(theme.language, english: "Core export is running...", chinese: "Core 正在导出...", italian: "Export Core in corso...", french: "Export Core en cours...", spanish: "Exportación Core en curso...")
        let target = archiveTargetPath(category: kind == "modpack" ? "Modpacks" : "Instances", suffix: kind)
        Task {
            do {
                let response = try await viewModel.archiveLocalDirectory(
                    sourcePath: effectiveGameDirectory,
                    targetPath: target
                )
                await MainActor.run {
                    isExporting = false
                    actionStatus = response.path ?? response.message
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    actionStatus = error.localizedDescription
                }
            }
        }
    }

    private func archiveTargetPath(category: String, suffix: String) -> String {
        let root = ((try? LauncherPaths.appSupportDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher", isDirectory: true))
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent(category, isDirectory: true)
        return root
            .appendingPathComponent("\(safeFileComponent(instance.name))-\(timestamp())-\(suffix).zip")
            .path
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var result = ""
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                result.append("-")
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-")).isEmpty ? "instance" : result
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private struct InstanceSavesPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let instance: GameInstance

    @EnvironmentObject private var theme: ThemeSettings
    @State private var preflight: CoreExportBackupPreflightResponse?
    @State private var preflightError = ""
    @State private var isCheckingPreflight = false
    @State private var actionStatus = ""
    @State private var isMutatingSaves = false

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"),
                    systemImage: "tray.full"
                )
                Text(localizedString(theme.language, english: "Save backup and import use this instance's private saves folder; archive creation and extraction are handled by Haskell Core.", chinese: "存档备份与导入只作用于此实例独立存档目录；压缩与解包由 Haskell Core 处理。", italian: "Backup/import usano la cartella salvataggi privata; il Core Haskell archivia/estrae.", french: "Sauvegarde/import utilisent le dossier privé ; le Core Haskell archive/extrait.", spanish: "Copia/importación usan la carpeta privada; Haskell Core archiva/extrae."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    saveMetric(localizedString(theme.language, english: "Configuration", chinese: "游戏配置", italian: "Configurazione", french: "Configuration", spanish: "Configuración"), instance.name)
                    saveMetric(localizedString(theme.language, english: "Saves Folder", chinese: "存档文件夹", italian: "Cartella salvataggi", french: "Dossier sauvegardes", spanish: "Carpeta de partidas"), savesPath)
                }

                HStack(spacing: 8) {
                    GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Run Preflight", chinese: "运行预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight")) {
                        runBackupPreflight()
                    }
                    .disabled(isCheckingPreflight)
                    GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Saves Folder", chinese: "打开存档文件夹", italian: "Apri salvataggi", french: "Ouvrir sauvegardes", spanish: "Abrir partidas")) {
                        FinderIntegration.openSavesDirectory(instance)
                    }
                    GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup Saves", chinese: "备份存档", italian: "Backup salvataggi", french: "Sauvegarder", spanish: "Respaldar partidas")) {
                        backupSaves()
                    }
                    .disabled(isMutatingSaves)
                    GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Import Saves", chinese: "导入存档", italian: "Importa salvataggi", french: "Importer", spanish: "Importar partidas")) {
                        importSaves()
                    }
                    .disabled(isMutatingSaves)
                }

                PreflightResultView(preflight: preflight, error: preflightError, isChecking: isCheckingPreflight)
                if !actionStatus.isEmpty {
                    Text(actionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func runBackupPreflight() {
        isCheckingPreflight = true
        preflightError = ""
        Task {
            do {
                let result = try await viewModel.exportBackupPreflight(for: instance, kind: "backup")
                await MainActor.run {
                    preflight = result
                    isCheckingPreflight = false
                }
            } catch {
                await MainActor.run {
                    preflight = nil
                    preflightError = error.localizedDescription
                    isCheckingPreflight = false
                }
            }
        }
    }

    private var savesPath: String {
        let base = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent("saves", isDirectory: true)
            .path
    }

    private var effectiveGameDirectory: String {
        instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func backupSaves() {
        guard !effectiveGameDirectory.isEmpty else {
            actionStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isMutatingSaves = true
        actionStatus = localizedString(theme.language, english: "Core save backup is running...", chinese: "Core 正在备份存档...", italian: "Backup Core in corso...", french: "Sauvegarde Core en cours...", spanish: "Copia Core en curso...")
        let target = archiveTargetPath()
        Task {
            do {
                let response = try await viewModel.archiveLocalDirectory(sourcePath: savesPath, targetPath: target)
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = response.path ?? response.message
                }
            } catch {
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = error.localizedDescription
                }
            }
        }
    }

    private func importSaves() {
        guard !effectiveGameDirectory.isEmpty else {
            actionStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = localizedString(theme.language, english: "Choose a Panino saves backup zip.", chinese: "选择一个 Panino 存档备份 zip。", italian: "Scegli zip backup salvataggi.", french: "Choisissez un zip de sauvegarde.", spanish: "Elige un zip de respaldo.")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isMutatingSaves = true
        actionStatus = localizedString(theme.language, english: "Core save import is running...", chinese: "Core 正在导入存档...", italian: "Import Core in corso...", french: "Import Core en cours...", spanish: "Importación Core en curso...")
        Task {
            do {
                let response = try await viewModel.importLocalArchive(archivePath: url.path, targetDir: effectiveGameDirectory)
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = response.path ?? response.message
                }
            } catch {
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = error.localizedDescription
                }
            }
        }
    }

    private func archiveTargetPath() -> String {
        let root = ((try? LauncherPaths.appSupportDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher", isDirectory: true))
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Saves", isDirectory: true)
        return root
            .appendingPathComponent("\(safeFileComponent(instance.name))-saves-\(timestamp()).zip")
            .path
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var result = ""
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                result.append("-")
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-")).isEmpty ? "saves" : result
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func saveMetric(_ title: String, _ value: String) -> some View {
        HStack(spacing: 0) {
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
}

private struct PreflightResultView: View {
    let preflight: CoreExportBackupPreflightResponse?
    let error: String
    let isChecking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isChecking {
                Text("Core preflight is running...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            } else if let preflight {
                Text(preflight.allowed ? "Preflight passed" : "Preflight blocked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(preflight.allowed ? Color.green : Color.orange)
                if let estimatedBytes = preflight.estimatedBytes {
                    Text(ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(preflight.blockingReasons + preflight.warnings, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CachedInstanceIcon: View {
    let instance: GameInstance
    var size: CGFloat = 54

    var body: some View {
        Image(systemName: instance.resolvedIconName)
            .font(.system(size: max(14, size * 0.42), weight: .semibold))
            .foregroundStyle(instance.coverTintColor)
            .frame(width: size, height: size)
            .background(instance.coverTintColor.opacity(0.14), in: RoundedRectangle(cornerRadius: min(10, size * 0.2)))
            .frame(width: size, height: size)
    }
}

enum InstanceManagementMode: String, CaseIterable, Identifiable {
    case versions
    case global

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .versions:
            return localizedString(language, english: "Version Management", chinese: "版本管理", italian: "Gestione versioni", french: "Gestion des versions", spanish: "Gestión de versiones")
        case .global:
            return localizedString(language, english: "Global Management", chinese: "全局管理", italian: "Gestione globale", french: "Gestion globale", spanish: "Gestión global")
        }
    }
}

enum InstancePropertySection: String, CaseIterable, Identifiable {
    case overview
    case settings
    case mods
    case resourcePacks
    case shaders
    case saves
    case export

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            return localizedString(language, english: "Overview", chinese: "概览", italian: "Panoramica", french: "Vue d'ensemble", spanish: "Resumen")
        case .settings:
            return AppText.settings.localized(language)
        case .mods:
            return "Mods"
        case .resourcePacks:
            return localizedString(language, english: "Resource Packs", chinese: "资源包", italian: "Pacchetti risorse", french: "Packs de ressources", spanish: "Paquetes de recursos")
        case .shaders:
            return localizedString(language, english: "Shaders", chinese: "光影包", italian: "Shader", french: "Shaders", spanish: "Shaders")
        case .saves:
            return localizedString(language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas")
        case .export:
            return AppText.export.localized(language)
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "cube.box"
        case .settings:
            return "slider.horizontal.3"
        case .mods:
            return "puzzlepiece.extension"
        case .resourcePacks:
            return "photo.on.rectangle"
        case .shaders:
            return "sparkles.rectangle.stack"
        case .saves:
            return "tray.full"
        case .export:
            return "shippingbox.and.arrow.up"
        }
    }

    var assetKind: ManagedAssetKind? {
        switch self {
        case .mods:
            return .mods
        case .resourcePacks:
            return .resourcePacks
        case .shaders:
            return .shaderPacks
        case .overview, .settings, .saves, .export:
            return nil
        }
    }

    static func section(for kind: ManagedAssetKind) -> InstancePropertySection? {
        switch kind {
        case .mods:
            return .mods
        case .resourcePacks:
            return .resourcePacks
        case .shaderPacks:
            return .shaders
        }
    }

    static func availableSections(for instance: GameInstance) -> [InstancePropertySection] {
        let capabilities = GameConfigurationCapabilities.capabilities(for: instance)
        return allCases.filter { section in
            switch section {
            case .mods:
                return capabilities.canManageMods
            case .shaders:
                return capabilities.canManageShaderPacks
            case .resourcePacks:
                return capabilities.canManageResourcePacks
            case .export:
                return capabilities.canExportModpack || instance.loader == nil
            case .overview, .settings, .saves:
                return true
            }
        }
    }
}

struct InstancesPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openResources: () -> Void
    let openDiscover: () -> Void
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var appActions: AppActionCenter
    @State private var searchText = ""
    @State private var sort: InstanceSort = .favoritesFirst
    @State private var filter: InstanceFilter = .all
    @State private var confirmDelete = false
    @State private var managementMode: InstanceManagementMode = .versions
    @State private var showingProperties = false
    @State private var propertySection: InstancePropertySection = .overview
    @State private var instanceOperationStatus = ""
    @State private var isMutatingInstance = false

    var body: some View {
        Group {
            if showingProperties, let binding = instanceStore.selectedInstanceBinding {
                InstancePropertiesPage(
                    viewModel: viewModel,
                    instance: binding,
                    section: $propertySection,
                    openDiscover: openDiscover,
                    onBack: { showingProperties = false },
                    onDuplicate: instanceStore.duplicateSelected,
                    onDelete: { confirmDelete = true },
                    onArchive: archiveSelectedInstance,
                    onMoveOut: moveOutSelectedInstance,
                    onRestoreArchive: restoreArchivedInstance
                )
            } else {
                instanceLibrary
            }
        }
        .task {
            configureVersionCoreBackend()
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: instanceStore.selectedInstanceID) {
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: instanceStore.selectedInstance?.minecraftVersion ?? "") {
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: appActions.instanceContentSequence) {
            openRequestedInstanceContent(appActions.requestedInstanceContentKind)
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete this game configuration?", chinese: "删除此游戏配置？", italian: "Eliminare questa configurazione?", french: "Supprimer cette configuration ?", spanish: "¿Eliminar esta configuración?"),
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(localizedString(theme.language, english: "Delete Game Configuration", chinese: "删除游戏配置", italian: "Elimina configurazione", french: "Supprimer configuration", spanish: "Eliminar configuración"), role: .destructive) {
                deleteSelectedInstanceFiles()
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            if let selected = instanceStore.selectedInstance {
                Text(deleteConfirmationMessage(selected))
            }
        }
    }

    private func openRequestedInstanceContent(_ kind: ManagedAssetKind?) {
        guard let kind, let section = InstancePropertySection.section(for: kind) else { return }
        guard let selected = instanceStore.selectedInstance else { return }
        let available = InstancePropertySection.availableSections(for: selected)
        guard available.contains(section) else { return }
        versionStore.selectedAssetKind = kind
        propertySection = section
        showingProperties = true
        versionStore.refreshAssets(for: selected)
    }

    private var instanceLibrary: some View {
        VStack(alignment: .leading, spacing: 12) {
            libraryToolbar

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    InstanceLibrarySidebar(
                        searchText: $searchText,
                        sort: $sort,
                        filter: $filter,
                        counts: collectionCounts
                    )
                    .frame(width: 232)

                    libraryGridSection
                }

                VStack(alignment: .leading, spacing: 12) {
                    libraryControls
                    libraryGridSection
                }
            }

            libraryStatus
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var libraryControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                compactControls
            }
            VStack(alignment: .leading, spacing: 10) {
                compactControls
            }
        }
    }

    @ViewBuilder
    private var compactControls: some View {
        PaninoTextInput(localizedString(theme.language, english: "Search installed instances", chinese: "搜索本地实例", italian: "Cerca istanze", french: "Rechercher instances", spanish: "Buscar instancias"), text: $searchText)
            .frame(minWidth: 240, idealWidth: 320, maxWidth: 360)
        Picker(localizedString(theme.language, english: "Sort"), selection: $sort) {
            ForEach(InstanceSort.allCases) { sort in
                Text(sort.title(language: theme.language)).tag(sort)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 150)
        Picker("", selection: $filter) {
            ForEach(InstanceFilter.allCases) { item in
                Text(item.title(language: theme.language)).tag(item)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 250)
    }

    private var libraryToolbar: some View {
        HStack {
            Spacer(minLength: 0)
            GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Restore Archive", chinese: "恢复归档", italian: "Ripristina archivio", french: "Restaurer archive", spanish: "Restaurar archivo")) {
                restoreArchivedInstance()
            }
            .disabled(isMutatingInstance)
        }
    }

    @ViewBuilder
    private var libraryGridSection: some View {
        if filteredInstances.isEmpty {
            GlassPanel(showsShadow: false) {
                ContentUnavailableView(
                    localizedString(theme.language, english: "No Installed Instance", chinese: "没有本地游戏实例", italian: "Nessuna istanza installata", french: "Aucune instance installée", spanish: "No hay instancia instalada"),
                    systemImage: "square.dashed",
                    description: Text(localizedString(theme.language, english: "Install Minecraft from Get first. Local instances appear after Core verifies the version files on disk.", chinese: "请先到“获取”页安装 Minecraft。Core 校验磁盘上的版本文件后，本地实例才会出现在这里。", italian: "Installa Minecraft da Ottieni.", french: "Installez Minecraft depuis Obtenir.", spanish: "Instala Minecraft desde Obtener."))
                )
            }
        } else {
            ScrollView {
                InstanceLibraryGrid(
                    instances: filteredInstances,
                    selectedInstanceID: instanceStore.selectedInstanceID,
                    canLaunch: viewModel.canSubmitTask,
                    selectInstance: { instance in
                        instanceStore.selectedInstanceID = instance.id
                    },
                    launch: { instance in
                        launchSelectedInstance(instance)
                    },
                    openProperties: { instance, section in
                        instanceStore.selectedInstanceID = instance.id
                        propertySection = section
                        showingProperties = true
                    },
                    openFolder: { instance in
                        FinderIntegration.openInstanceDirectory(instance)
                    }
                )
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var libraryStatus: some View {
        if !instanceStore.storageStatus.isEmpty || !instanceOperationStatus.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                if !instanceStore.storageStatus.isEmpty {
                    Text(instanceStore.storageStatus)
                        .lineLimit(1)
                }
                if !instanceOperationStatus.isEmpty {
                    Text(instanceOperationStatus)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var filteredInstances: [GameInstance] {
        sortInstances(searchMatchedInstances.filter { matchesFilter($0, filter: filter) })
    }

    private var collectionCounts: [InstanceFilter: Int] {
        Dictionary(uniqueKeysWithValues: InstanceFilter.allCases.map { item in
            (item, searchMatchedInstances.filter { matchesFilter($0, filter: item) }.count)
        })
    }

    private var searchMatchedInstances: [GameInstance] {
        instanceStore.instances.filter { instance in
            searchText.isEmpty
                || instance.name.localizedCaseInsensitiveContains(searchText)
                || instance.minecraftVersion.localizedCaseInsensitiveContains(searchText)
                || instance.group.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func sortInstances(_ instances: [GameInstance]) -> [GameInstance] {
        switch sort {
        case .favoritesFirst:
            return instances.sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .name:
            return instances.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private func matchesFilter(_ instance: GameInstance, filter: InstanceFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .favorites:
            return instance.isFavorite
        case .needsAttention:
            return instance.status == .failed || instance.status == .notInstalled
        }
    }

    private func launchSelectedInstance(_ instance: GameInstance) {
        viewModel.version = instance.minecraftVersion
        let usesGlobalRuntime = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        viewModel.memoryMb = usesGlobalRuntime ? SettingsStore.memoryMb : instance.memoryMb
        viewModel.javaPath = usesGlobalRuntime ? SettingsStore.javaPath : instance.javaPath
        if let loader = instance.loader {
            versionStore.selectedLoader = loader
        }
        viewModel.launch(
            accountID: accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID,
            gameDir: instance.gameDirectory,
            instance: instance
        )
    }

    private func deleteConfirmationMessage(_ instance: GameInstance) -> String {
        let directory = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return localizedString(
            theme.language,
            english: "\(instance.name)\nFolder: \(directory)\nThis moves the whole isolated instance folder to Trash and removes the local record.",
            chinese: "\(instance.name)\n目录：\(directory)\n这会把整个隔离实例目录移到废纸篓，并移除本地记录。",
            italian: "\(instance.name)\nCartella: \(directory)\nSposta l'intera istanza nel Cestino.",
            french: "\(instance.name)\nDossier : \(directory)\nDéplace toute l'instance dans la Corbeille.",
            spanish: "\(instance.name)\nCarpeta: \(directory)\nMueve toda la instancia a la Papelera."
        )
    }

    private func archiveSelectedInstance() {
        guard let instance = instanceStore.selectedInstance else { return }
        guard let sourcePath = isolatedDirectoryPath(for: instance) else {
            instanceOperationStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is archiving the instance...", chinese: "Core 正在归档实例...", italian: "Core archivia l'istanza...", french: "Core archive l'instance...", spanish: "Core está archivando la instancia...")
        let targetPath = instanceArchiveTargetPath(instance: instance, suffix: "instance")
        Task {
            await runInstanceArchive(instance: instance, sourcePath: sourcePath, targetPath: targetPath, removeAfterArchive: false)
        }
    }

    private func moveOutSelectedInstance() {
        guard let instance = instanceStore.selectedInstance else { return }
        guard let sourcePath = isolatedDirectoryPath(for: instance) else {
            instanceOperationStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is archiving and moving out the instance...", chinese: "Core 正在归档并移出实例...", italian: "Core archivia e sposta fuori l'istanza...", french: "Core archive et déplace l'instance...", spanish: "Core está archivando y moviendo la instancia...")
        let targetPath = instanceArchiveTargetPath(instance: instance, suffix: "moved-out")
        Task {
            await runInstanceArchive(instance: instance, sourcePath: sourcePath, targetPath: targetPath, removeAfterArchive: true)
        }
    }

    private func deleteSelectedInstanceFiles() {
        guard let instance = instanceStore.selectedInstance else { return }
        guard let sourcePath = isolatedDirectoryPath(for: instance) else {
            instanceStore.remove(instance)
            showingProperties = false
            return
        }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is moving the instance to Trash...", chinese: "Core 正在把实例移到废纸篓...", italian: "Core sposta l'istanza nel Cestino...", french: "Core déplace l'instance dans la Corbeille...", spanish: "Core está moviendo la instancia a la Papelera...")
        Task {
            do {
                let response = try await viewModel.deleteLocalResource(path: sourcePath)
                await MainActor.run {
                    instanceStore.remove(instance)
                    showingProperties = false
                    isMutatingInstance = false
                    instanceOperationStatus = response.path ?? response.message
                    refreshSelectedInstanceVersionState()
                }
            } catch {
                await MainActor.run {
                    isMutatingInstance = false
                    instanceOperationStatus = error.localizedDescription
                }
            }
        }
    }

    private func restoreArchivedInstance() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = localizedString(theme.language, english: "Choose an archived Panino instance zip.", chinese: "选择一个 Panino 实例归档 zip。", italian: "Scegli zip istanza Panino.", french: "Choisissez une archive d'instance Panino.", spanish: "Elige un zip de instancia Panino.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isMutatingInstance = true
        instanceOperationStatus = localizedString(theme.language, english: "Core is restoring the archived instance...", chinese: "Core 正在恢复归档实例...", italian: "Core ripristina l'istanza...", french: "Core restaure l'instance...", spanish: "Core está restaurando la instancia...")
        let targetRoot = ((try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true))
            .path
        Task {
            do {
                let response = try await viewModel.importLocalArchive(archivePath: url.path, targetDir: targetRoot, deleteArchive: true)
                await MainActor.run {
                    isMutatingInstance = false
                    instanceOperationStatus = response.message
                    refreshSelectedInstanceVersionState()
                }
            } catch {
                await MainActor.run {
                    isMutatingInstance = false
                    instanceOperationStatus = error.localizedDescription
                }
            }
        }
    }

    private func runInstanceArchive(instance: GameInstance, sourcePath: String, targetPath: String, removeAfterArchive: Bool) async {
        do {
            let archiveResponse = try await viewModel.archiveLocalDirectory(sourcePath: sourcePath, targetPath: targetPath)
            if removeAfterArchive {
                _ = try await viewModel.deleteLocalResource(path: sourcePath)
            }
            await MainActor.run {
                if removeAfterArchive {
                    instanceStore.remove(instance)
                    showingProperties = false
                }
                isMutatingInstance = false
                instanceOperationStatus = archiveResponse.path ?? archiveResponse.message
                refreshSelectedInstanceVersionState()
            }
        } catch {
            await MainActor.run {
                isMutatingInstance = false
                instanceOperationStatus = error.localizedDescription
            }
        }
    }

    private func isolatedDirectoryPath(for instance: GameInstance) -> String? {
        let path = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        guard let root = try? LauncherPaths.gameConfigurationsDirectory().standardizedFileURL.path else {
            return nil
        }
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        guard standardized == root || standardized.hasPrefix(root + "/") else { return nil }
        return standardized
    }

    private func instanceArchiveTargetPath(instance: GameInstance, suffix: String) -> String {
        let root = ((try? LauncherPaths.backupsDirectory(category: "Instances"))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher/Backups/Instances", isDirectory: true))
        return root
            .appendingPathComponent("\(safeFileComponent(instance.name))-\(timestamp())-\(suffix).zip")
            .path
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var result = ""
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "instance" : trimmed
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func refreshSelectedInstanceVersionState() {
        configureVersionCoreBackend()
        guard let selected = instanceStore.selectedInstance else {
            versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
            return
        }
        versionStore.selectedVersionID = selected.minecraftVersion
        versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
        versionStore.loadDetails(
            for: versionStore.versions.first { $0.id == selected.minecraftVersion },
            instances: instanceStore.instances,
            settings: launcherSettings
        )
    }

    private func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: VersionContentCoreBackend(
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftInstallStatus: { versionIds, gameDirs in
                    try await viewModel.minecraftInstallStatus(versionIds: versionIds, gameDirs: gameDirs)
                },
                installedMinecraftInstances: { versionIds, gameDirs in
                    try await viewModel.installedMinecraftInstances(versionIds: versionIds, gameDirs: gameDirs)
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                localResources: { gameDir, kind, loader in
                    try await viewModel.localResources(gameDir: gameDir, kind: kind, loader: loader)
                },
                toggleLocalResource: { path in
                    try await viewModel.toggleLocalResource(path: path)
                },
                deleteLocalResource: { path in
                    try await viewModel.deleteLocalResource(path: path)
                },
                importLocalResource: { sourcePath, gameDir, kind in
                    try await viewModel.importLocalResource(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
                },
                cleanMinecraftVersion: { version, gameDir in
                    try await viewModel.cleanMinecraftVersion(version: version, gameDir: gameDir)
                },
                mutateMinecraftVersionStorage: { version, gameDir, action in
                    try await viewModel.mutateMinecraftVersionStorage(version: version, gameDir: gameDir, action: action)
                }
            )
        )
    }
}
