import SwiftUI

struct VersionStorageControls: View {
    let version: MinecraftVersionInfo?
    let canArchive: (MinecraftVersionInfo) -> Bool
    let canDelete: (MinecraftVersionInfo) -> Bool
    let selectAction: (VersionStorageConfirmation) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
            selectAction(.archive)
        }
        .disabled(!canArchive(version))

        GlassButton(
            systemImage: "arrow.up.bin",
            title: localizedString(theme.language, english: "Restore", chinese: "移出归档", italian: "Ripristina", french: "Restaurer", spanish: "Restaurar")
        ) {
            selectAction(.restore)
        }
        .disabled(!version.isArchived || version.isInstalled)

        GlassButton(
            systemImage: "trash",
            title: AppText.delete.localized(theme.language)
        ) {
            selectAction(.delete)
        }
        .disabled(!canDelete(version))
    }
}
