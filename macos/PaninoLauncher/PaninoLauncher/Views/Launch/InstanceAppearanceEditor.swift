import SwiftUI

struct InstanceAppearanceValues: Equatable {
    var iconName: String
    var coverPath: String
    var coverColorHex: String
    var coverFocusX: Double
    var coverFocusY: Double
    var coverBlur: Double
    var coverDim: Double
    var iconBackdropStyle: InstanceIconBackdropStyle

    init(instance: GameInstance) {
        iconName = instance.iconName
        coverPath = instance.coverPath
        coverColorHex = instance.coverColorHex
        coverFocusX = instance.coverFocusX
        coverFocusY = instance.coverFocusY
        coverBlur = instance.coverBlur
        coverDim = instance.coverDim
        iconBackdropStyle = instance.iconBackdropStyle
    }
}

extension GameInstance {
    mutating func applyAppearance(_ values: InstanceAppearanceValues) {
        iconName = values.iconName
        coverPath = values.coverPath
        coverColorHex = values.coverColorHex
        coverFocusX = values.coverFocusX
        coverFocusY = values.coverFocusY
        coverBlur = values.coverBlur
        coverDim = values.coverDim
        iconBackdropStyle = values.iconBackdropStyle
    }
}

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

            InstanceAppearanceSection(
                title: localizedString(theme.language, english: "Color", chinese: "颜色", italian: "Colore", french: "Couleur", spanish: "Color"),
                systemImage: "swatchpalette"
            ) {
                HStack(spacing: 10) {
                    ColorPicker("", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                    Text(values.coverColorHex.uppercased())
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(InstanceAppearanceColorPreset.allCases) { preset in
                        Button {
                            values.coverColorHex = preset.hex
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color.paninoHex(preset.hex, fallback: theme.semanticSelectionColor))
                                    .frame(width: 28, height: 28)
                                Text(preset.title(language: theme.language))
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(
                                selectedColor(preset) ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.32),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selectedColor(preset) ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            InstanceAppearanceSection(
                title: localizedString(theme.language, english: "Image", chinese: "图片", italian: "Immagine", french: "Image", spanish: "Imagen"),
                systemImage: "photo"
            ) {
                HStack(spacing: 8) {
                    PaninoTextInput(
                        localizedString(theme.language, english: "Cover image path", chinese: "横幅图片路径", italian: "Percorso immagine", french: "Chemin de l'image", spanish: "Ruta de imagen"),
                        text: $values.coverPath
                    )
                    GlassButton(systemImage: "folder", title: AppText.choose.localized(theme.language)) {
                        isImportingCover = true
                    }
                    GlassButton(systemImage: "xmark.circle", title: localizedString(theme.language, english: "Clear", chinese: "清除", italian: "Cancella", french: "Effacer", spanish: "Borrar")) {
                        values.coverPath = ""
                    }
                    .disabled(values.coverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                InstanceAppearanceSlider(
                    title: localizedString(theme.language, english: "Horizontal Focus", chinese: "水平焦点", italian: "Fuoco orizzontale", french: "Point horizontal", spanish: "Enfoque horizontal"),
                    value: $values.coverFocusX
                )
                InstanceAppearanceSlider(
                    title: localizedString(theme.language, english: "Vertical Focus", chinese: "垂直焦点", italian: "Fuoco verticale", french: "Point vertical", spanish: "Enfoque vertical"),
                    value: $values.coverFocusY
                )
                InstanceAppearanceSlider(
                    title: localizedString(theme.language, english: "Cover Blur", chinese: "封面模糊", italian: "Sfocatura copertina", french: "Flou couverture", spanish: "Desenfoque portada"),
                    value: $values.coverBlur
                )
                InstanceAppearanceSlider(
                    title: localizedString(theme.language, english: "Cover Dim", chinese: "封面暗化", italian: "Oscura copertina", french: "Assombrir couverture", spanish: "Oscurecer portada"),
                    value: $values.coverDim
                )
            }

            InstanceAppearanceSection(
                title: localizedString(theme.language, english: "Icon", chinese: "图标", italian: "Icona", french: "Icône", spanish: "Icono"),
                systemImage: "square.grid.3x3"
            ) {
                Picker(localizedString(theme.language, english: "Backdrop", chinese: "底板", italian: "Sfondo", french: "Fond", spanish: "Fondo"), selection: $values.iconBackdropStyle) {
                    ForEach(InstanceIconBackdropStyle.allCases) { style in
                        Text(style.title(language: theme.language)).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(InstanceAppearanceIconPreset.allCases) { preset in
                        Button {
                            values.iconName = preset.systemName
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: preset.systemName)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor))
                                Text(preset.title(language: theme.language))
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 66)
                            .background(
                                selectedIcon(preset) ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.32),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selectedIcon(preset) ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                PaninoTextInput(
                    localizedString(theme.language, english: "SF Symbol name", chinese: "SF Symbol 名称", italian: "Nome SF Symbol", french: "Nom SF Symbol", spanish: "Nombre SF Symbol"),
                    text: $values.iconName
                )
            }

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

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor) },
            set: { color in
                if let hex = color.paninoHexString {
                    values.coverColorHex = hex
                }
            }
        )
    }

    private func selectedColor(_ preset: InstanceAppearanceColorPreset) -> Bool {
        values.coverColorHex.normalizedHex == preset.hex.normalizedHex
    }

    private func selectedIcon(_ preset: InstanceAppearanceIconPreset) -> Bool {
        values.iconName == preset.systemName
    }
}
