import SwiftUI

struct InstanceVersionCardSection: View {
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

enum VersionStorageConfirmation: String, Identifiable {
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
