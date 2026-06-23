import SwiftUI

struct SelectedAssetActionBar: View {
    let selectedCount: Int
    let update: () -> Void
    let enable: () -> Void
    let disable: () -> Void
    let delete: () -> Void
    let deselect: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            HStack(spacing: 10) {
                PlainStatusText(
                    title: localizedString(theme.language, english: "\(selectedCount) selected", chinese: "已选 \(selectedCount) 个", italian: "\(selectedCount) selezionati", french: "\(selectedCount) sélectionnés", spanish: "\(selectedCount) seleccionados"),
                    style: .download
                )
                Spacer()
                GlassButton(systemImage: "arrow.up.circle", title: localizedString(theme.language, english: "Update", chinese: "更新", italian: "Aggiorna", french: "Mettre à jour", spanish: "Actualizar"), action: update)
                GlassButton(systemImage: "play", title: AppText.enable.localized(theme.language), action: enable)
                GlassButton(systemImage: "pause", title: AppText.disable.localized(theme.language), action: disable)
                GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: delete)
                GlassButton(systemImage: "xmark", title: localizedString(theme.language, english: "Deselect", chinese: "取消选择", italian: "Deseleziona", french: "Désélectionner", spanish: "Deseleccionar"), action: deselect)
            }
        }
    }
}
