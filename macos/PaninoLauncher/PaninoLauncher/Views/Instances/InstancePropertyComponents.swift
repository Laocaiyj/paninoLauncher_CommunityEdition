import SwiftUI

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
