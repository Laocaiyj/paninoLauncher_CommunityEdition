import AppKit
import SwiftUI

struct InstanceImmersiveBackground: View {
    let instance: GameInstance?

    @EnvironmentObject private var theme: ThemeSettings
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [
                            tint.opacity(0.68),
                            theme.semanticSelectionColor.opacity(0.30),
                            Color(nsColor: .windowBackgroundColor).opacity(0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: instance?.resolvedIconName ?? "square.stack.3d.up")
                        .font(.system(size: 190, weight: .bold))
                        .foregroundStyle(tint.opacity(0.22))
                        .offset(x: proxy.size.width * 0.25, y: -proxy.size.height * 0.12)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: instance?.coverPath ?? "") {
            guard let instance, !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 1280, height: 720))
        }
    }

    private var tint: Color {
        instance?.coverTintColor ?? theme.semanticSelectionColor
    }
}

struct InstanceImmersivePrimary: View {
    let instance: GameInstance?
    let totalCount: Int
    let filteredCount: Int
    let statusText: String
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let instance {
                MetadataLine(items: [
                    "Minecraft \(instance.minecraftVersion)",
                    instance.loaderTitle(language: theme.language),
                    instance.group
                ])
                .foregroundStyle(.white.opacity(0.82))

                Text(instance.name)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.42), radius: 10, x: 0, y: 4)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { facts(instance) }
                    VStack(alignment: .leading, spacing: 8) { facts(instance) }
                }

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 4, tint: instance.coverTintColor)
                }
            } else {
                Text(localizedString(theme.language, english: "No local instances", chinese: "还没有本地实例", italian: "Nessuna istanza locale", french: "Aucune instance locale", spanish: "Sin instancias locales"))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

                Text(localizedString(theme.language, english: "Install Minecraft from Get. Verified instances will appear here as playable scenes.", chinese: "从“获取”安装 Minecraft。校验完成的实例会作为可游玩的场景显示在这里。", italian: "Installa Minecraft da Ottieni.", french: "Installez Minecraft depuis Obtenir.", spanish: "Instala Minecraft desde Obtener."))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
                    .frame(maxWidth: 560, alignment: .leading)

                GlassButton(
                    systemImage: "arrow.down.circle",
                    title: localizedString(theme.language, english: "Get Minecraft", chinese: "获取 Minecraft", italian: "Ottieni Minecraft", french: "Obtenir Minecraft", spanish: "Obtener Minecraft"),
                    prominent: true,
                    action: openDiscover
                )
            }
        }
        .frame(maxWidth: 820, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func facts(_ instance: GameInstance) -> some View {
        ImmersiveTextPill(title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "État", spanish: "Estado"), value: instance.status.title(language: theme.language)) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(instance.status.badgeStyle.color)
                .frame(width: 3, height: 18)
        }
        ImmersiveTextPill(title: localizedString(theme.language, english: "Memory", chinese: "内存", italian: "Memoria", french: "Mémoire", spanish: "Memoria"), value: "\(instance.memoryMb) MB")
        ImmersiveTextPill(title: localizedString(theme.language, english: "Library", chinese: "库", italian: "Libreria", french: "Bibliothèque", spanish: "Biblioteca"), value: "\(filteredCount) / \(totalCount)")
    }
}

struct InstanceImmersiveControls: View {
    let instance: GameInstance?
    let canSubmitTask: Bool
    let isMutatingInstance: Bool
    let launch: (GameInstance) -> Void
    let openProperties: (GameInstance) -> Void
    let openFolder: (GameInstance) -> Void
    let restoreArchive: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { controls }
            VStack(alignment: .trailing, spacing: 10) { controls }
        }
        .padding(8)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 10, tint: instance?.coverTintColor ?? theme.semanticSelectionColor, showsShadow: true)
    }

    @ViewBuilder
    private var controls: some View {
        if let instance {
            GlassButton(systemImage: "play.fill", title: AppText.launch.localized(theme.language), prominent: true) {
                launch(instance)
            }
            .disabled(!canSubmitTask || !GameConfigurationCapabilities.capabilities(for: instance).canLaunch)

            GlassButton(systemImage: "slider.horizontal.3", title: localizedString(theme.language, english: "Properties", chinese: "属性", italian: "Proprietà", french: "Propriétés", spanish: "Propiedades")) {
                openProperties(instance)
            }

            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                openFolder(instance)
            }
        } else {
            GlassButton(systemImage: "arrow.down.circle", title: localizedString(theme.language, english: "Get", chinese: "获取", italian: "Ottieni", french: "Obtenir", spanish: "Obtener"), prominent: true, action: openDiscover)
        }

        GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Restore Archive", chinese: "恢复归档", italian: "Ripristina archivio", french: "Restaurer archive", spanish: "Restaurar archivo"), action: restoreArchive)
            .disabled(isMutatingInstance)
    }
}

struct InstanceImmersiveShelf: View {
    @Binding var searchText: String
    @Binding var sort: InstanceSort
    @Binding var filter: InstanceFilter
    let counts: [InstanceFilter: Int]
    let instances: [GameInstance]
    let selectedInstanceID: UUID?
    let canLaunch: Bool
    let selectInstance: (GameInstance) -> Void
    let launch: (GameInstance) -> Void
    let openProperties: (GameInstance, InstancePropertySection) -> Void
    let openFolder: (GameInstance) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    controls
                }
                VStack(alignment: .leading, spacing: 10) {
                    controls
                }
            }

            if instances.isEmpty {
                EmptyStateInline(
                    title: localizedString(theme.language, english: "No matching instance", chinese: "没有匹配的实例", italian: "Nessuna istanza", french: "Aucune instance", spanish: "Sin instancias"),
                    message: localizedString(theme.language, english: "Adjust search or filters, or install Minecraft from Get.", chinese: "调整搜索/筛选，或从“获取”安装 Minecraft。", italian: "Modifica ricerca o filtri.", french: "Ajustez recherche ou filtres.", spanish: "Ajusta búsqueda o filtros."),
                    systemImage: "magnifyingglass"
                )
                .frame(minHeight: 82)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
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
                            .frame(width: 300)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.panel, tint: theme.semanticSelectionColor, showsShadow: true)
    }

    @ViewBuilder
    private var controls: some View {
        PaninoTextInput(localizedString(theme.language, english: "Search installed instances", chinese: "搜索本地实例", italian: "Cerca istanze", french: "Rechercher instances", spanish: "Buscar instancias"), text: $searchText)
            .frame(minWidth: 240, idealWidth: 320, maxWidth: 360)

        Picker(localizedString(theme.language, english: "Sort"), selection: $sort) {
            ForEach(InstanceSort.allCases) { sort in
                Text(sort.title(language: theme.language)).tag(sort)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 150)

        PaninoGlassSegmentedRail {
            Picker("", selection: $filter) {
                ForEach(InstanceFilter.allCases) { item in
                    Text("\(item.title(language: theme.language)) \(counts[item] ?? 0)").tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 310)
        }
    }
}
