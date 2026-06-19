import SwiftUI

struct InstancePropertyOverview: View {
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
            summaryPanel
            personalizationPanel
            shortcutsPanel(capabilities: capabilities)
            advancedOptions
        }
    }

    private var summaryPanel: some View {
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
    }

    private var personalizationPanel: some View {
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
    }

    private func shortcutsPanel(capabilities: GameConfigurationCapabilities) -> some View {
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
    }

    private var advancedOptions: some View {
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
