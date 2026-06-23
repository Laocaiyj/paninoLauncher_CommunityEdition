import SwiftUI

struct InstanceAppearanceEditor: View {
    let instance: GameInstance
    let onSave: (InstanceAppearanceValues) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeSettings
    @State private var values: InstanceAppearanceValues
    @State private var importedImageError: String?
    @State private var isImportingCover = false

    init(instance: GameInstance, onSave: @escaping (InstanceAppearanceValues) -> Void) {
        self.instance = instance
        self.onSave = onSave
        _values = State(initialValue: InstanceAppearanceValues(instance: instance))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Instance Appearance", chinese: "实例外观", italian: "Aspetto istanza", french: "Apparence de l'instance", spanish: "Apariencia de instancia"),
                    systemImage: "paintpalette"
                )
                Spacer()
                GlassButton(systemImage: "arrow.counterclockwise", title: localizedString(theme.language, english: "Reset", chinese: "重置", italian: "Ripristina", french: "Réinitialiser", spanish: "Restablecer")) {
                    values = InstanceAppearanceValues(instance: instance)
                }
            }

            InstanceAppearancePreview(instance: instance, values: values)
                .frame(height: 180)

            InstanceAppearanceColorSection(values: $values)

            InstanceAppearanceImageSection(values: $values) {
                isImportingCover = true
            }

            InstanceAppearanceIconSection(values: $values)

            HStack {
                Spacer()
                GlassButton(systemImage: "xmark", title: AppText.cancel.localized(theme.language)) {
                    dismiss()
                }
                GlassButton(systemImage: "checkmark", title: AppText.apply.localized(theme.language), prominent: true) {
                    onSave(values.normalized)
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, idealWidth: 700, maxWidth: 760)
        .fileImporter(
            isPresented: $isImportingCover,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                values.coverPath = urls.first?.path ?? values.coverPath
            case .failure(let error):
                importedImageError = error.localizedDescription
            }
        }
        .alert(
            localizedString(theme.language, english: "Image Import Failed", chinese: "图片导入失败", italian: "Importazione immagine non riuscita", french: "Échec de l'importation", spanish: "Error al importar imagen"),
            isPresented: Binding(
                get: { importedImageError != nil },
                set: { if !$0 { importedImageError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importedImageError ?? "")
        }
    }
}
