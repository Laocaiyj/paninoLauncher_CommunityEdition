import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InstancePropertiesPage: View {
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
                case .multiplayer:
                    TaowaMultiplayerPage(viewModel: viewModel, instance: instance)
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

enum InstancePropertySection: String, CaseIterable, Identifiable {
    case overview
    case settings
    case multiplayer
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
        case .multiplayer:
            return localizedString(language, english: "Multiplayer", chinese: "联机", italian: "Multigiocatore", french: "Multijoueur", spanish: "Multijugador")
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
        case .multiplayer:
            return "network"
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
        case .overview, .settings, .multiplayer, .saves, .export:
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
            case .overview, .settings, .multiplayer, .saves:
                return true
            }
        }
    }
}
